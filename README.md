# dbt Project

Transformation layer of the data pipeline factory. Reads raw JSON landed by the scrapers repo and progressively models it into clean, typed, business-ready tables through a medallion architecture. No ingestion or orchestration code lives here.

## How it was built

1. Initialised a dbt Core project with the `dbt-bigquery` adapter
2. Connected to BigQuery using a service account via `profiles.yml`
3. Wrote a `generate_schema_name.sql` macro so models land in clean dataset names (`brz_football`, `slv_football`) instead of dbt's default prefixed naming
4. Wrote a `flatten_json` macro that parses the raw `data` JSON field into typed columns, reused across every bronze model regardless of source
5. Declared each source's raw BigQuery output as a dbt source (`_sources.yml`), so bronze models reference it with `source()` rather than hardcoded table names
6. Built bronze models (parse and type) and silver models (clean, deduplicate, apply business logic) per source
7. Added a `scd_type2.sql` macro for dimensions that need historical change tracking
8. Added singular and generic tests under `tests/`, organised by source
9. Added a `documentation/` folder so every source carries its own README and changelog, separate from dbt's own docs

## Project structure

```
dbt/
├── data_transformation/
│   ├── dbt_project.yml
│   ├── macros/
│   │   ├── flatten_json.sql              # parses raw JSON into typed columns
│   │   ├── generate_schema_name.sql      # clean dataset naming
│   │   └── scd_type2.sql                 # reusable SCD Type 2 snapshot logic
│   ├── models/
│   │   ├── bronze_layer/
│   │   │   └── <source>/
│   │   │       ├── _sources.yml          # declares the raw dataset for this source
│   │   │       └── brz_<source>__*.sql
│   │   └── silver_layer/
│   │       └── <source>/
│   │           ├── _models.yml           # docs + dbt tests
│   │           └── slv_<source>__*.sql
│   └── tests/
│       ├── generic/                      # reusable custom test definitions
│       │   └── tst_*.sql
│       └── singular/
│           └── <source>/                 # one-off business-rule tests per source
│               └── *.sql
├── documentation/
│   ├── readme/
│   │   └── <source>_README.md            # what the source is, how it's modelled
│   └── changelog/
│       └── <source>_CHANGELOG.md         # dated log of changes to that source's models
├── requirements.txt
└── README.md
```

A new source adds one folder under `bronze_layer/`, one under `silver_layer/`, optionally a folder under `tests/singular/`, and one README/changelog pair under `documentation/`. Nothing outside those additions changes.

## The medallion layers

| Layer | Dataset | What happens |
|---|---|---|
| Raw | source-specific raw dataset | Unmodified JSON, written by the scrapers repo. Never touched by dbt. |
| Bronze | `brz_<source>` | `flatten_json` parses the JSON, casts types, standardises column names. No business logic. |
| Silver | `slv_<source>` | Deduplication, null handling, business rules. Structured as fact/dimension tables where applicable. |
| Gold  | `gld_<source>` | Aggregated metrics ready for BI tools. |

## Macros

| Macro | Purpose |
|---|---|
| `flatten_json.sql` | Parses the raw `data` JSON string field into typed columns. Takes a list of keys and nesting level, so the same logic works for any source's bronze model. |
| `generate_schema_name.sql` | Overrides dbt's default schema naming so datasets are named cleanly (`brz_football`) instead of prefixed (`dbt_dev_brz_football`). |
| `scd_type2.sql` | Reusable Slowly Changing Dimension Type 2 logic for dimensions that need historical tracking (e.g. team or player attribute changes over time). |

## Tests

| Folder | Purpose |
|---|---|
| `tests/generic/` | Custom reusable test definitions, callable like any built-in dbt test (e.g. `tst_expect_single_distinct_value_per_group`) |
| `tests/singular/<source>/` | One-off SQL assertions specific to a source's business rules, named by ticket/reference (e.g. `CPL-FOT-001.sql`) |

Standard dbt tests (`not_null`, `unique`, `accepted_values`, `relationships`) are declared directly in each source's `_models.yml`.

## Documentation

Each source gets its own README and changelog under `documentation/`, kept separate from this top-level README:

| File | Purpose |
|---|---|
| `documentation/readme/<source>_README.md` | What the source is, what it tracks, how bronze and silver model it |
| `documentation/changelog/<source>_CHANGELOG.md` | Dated log of changes to that source's models, macros used, or schema |

This keeps source-specific detail out of the top-level README and makes it easy to onboard a new source without touching documentation for existing ones.

## Setup

Requires Python 3.11+ and dbt Core.

```powershell
pip install -r requirements.txt
```

Create `profiles.yml` (not committed — contains credentials):

```yaml
dbt_project:
  outputs:
    dev:
      type: bigquery
      method: service-account
      project: your-gcp-project-id
      dataset: dev_yourname
      keyfile: path\to\service-account.json
      location: US
      threads: 4
  target: dev
```

## Usage

**Run all bronze models for a source:**

```powershell
dbt run --select bronze_layer.bronze_football --profile dbt_project --target dev
```

**Run all silver models for a source:**

```powershell
dbt run --select silver_layer.silver_football --profile dbt_project --target dev
```

**Run tests for a source:**

```powershell
dbt test --select silver_layer.silver_football --profile dbt_project --target dev
```

**Run a single singular test:**

```powershell
dbt test --select CPL-FOT-001
```

**Compile without running (useful for debugging macros):**

```powershell
dbt compile --select bronze_layer.bronze_football
```

In production this repo is never run manually — Airflow triggers these same commands through Astro Cosmos on a schedule, after confirming the source spiders succeeded.

## Adding a new source

1. Add the new raw table to a new `_sources.yml` under `models/bronze_layer/<source>/`
2. Write bronze model(s) that call `flatten_json` on the new source
3. Write silver model(s) that clean and apply business logic to the bronze output, using `scd_type2` if the dimension needs historical tracking
4. Add any source-specific business-rule tests under `tests/singular/<source>/`
5. Add `documentation/readme/<source>_README.md` and `documentation/changelog/<source>_CHANGELOG.md`
6. Reference the new models in the corresponding pipeline's `dbt_selects` in the airflow repo's `spiders_config.yaml`

No changes to macros, project config, or this top-level README are needed for a new source — everything reusable is already in place.

## Why a `flatten_json` macro instead of hardcoded columns

Hardcoding `JSON_VALUE(data, '$.field')` calls in every model ties each model to one specific source's shape. The macro takes a list of keys and a nesting level, so the same logic parses any source — only the macro call's arguments change, not the underlying SQL pattern.

## Why a dedicated `documentation/` folder

dbt's built-in docs describe models and columns, not the reasoning behind a source's design or its history of changes. Splitting source-level README and changelog content into its own folder keeps that narrative documentation versioned alongside the code without cluttering the top-level project README as more sources are added.
