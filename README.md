# dbt CI/CD Demo: Dev → Test → Prod on Snowflake

A small dbt project built on `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1`, so it needs no data loading. It shows code moving through three Snowflake environments with GitHub Actions. The same repo then connects to dbt Cloud.

```
feature branch ──► Pull Request ──────────► merge to main
     DEV               TEST                     PROD
 (developer IDE /   dbt_ci_test.yml          dbt_cd_prod.yml
  local dbt)        PR_<n> schema in         DBT_DEMO_PROD, gated by
  DBT_DEMO_DEV      DBT_DEMO_TEST, dropped   "production" env approval
                    after the run
```

| Env  | Database        | Role                 | Who runs it                       |
|------|-----------------|----------------------|-----------------------------------|
| dev  | `DBT_DEMO_DEV`  | `DBT_DEMO_DEV_ROLE`  | Developer (local or dbt Cloud IDE), schema `DBT_<name>` |
| test | `DBT_DEMO_TEST` | `DBT_DEMO_TEST_ROLE` | GitHub Actions on every PR (Slim CI) |
| prod | `DBT_DEMO_PROD` | `DBT_DEMO_PROD_ROLE` | GitHub Actions on merge to `main`  |

## Project layout

```
models/staging/   stg_orders, stg_customers (views) + source + tests
models/marts/     fct_customer_revenue (table) + tests
macros/           generate_schema_name (clean names in prod, prefixed names elsewhere)
                  drop_ci_schemas (cleans up PR schemas)
tests/            singular test: assert_revenue_positive
profiles.yml      dev/test/prod targets (GitHub + local only; dbt Cloud ignores it)
setup/            01_snowflake_setup.sql
.github/workflows dbt_ci_test.yml, dbt_cd_prod.yml
```

`stg_orders` filters to 1998 outside prod, so dev and test row counts are smaller than prod. That makes environment differences easy to point at during the demo.

## 1. Snowflake setup (one time)

1. Generate two key pairs, one for GitHub and one for dbt Cloud:
   ```bash
   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out github_key.p8 -nocrypt
   openssl rsa -in github_key.p8 -pubout -out github_key.pub
   # repeat for dbt_cloud_key.p8 / dbt_cloud_key.pub
   ```
2. Paste the public key bodies into `setup/01_snowflake_setup.sql` and run it as ACCOUNTADMIN.

## 2. GitHub setup

1. Create the repo and push this folder to it.
2. **Settings → Secrets and variables → Actions**
   - Variable `SNOWFLAKE_ACCOUNT` = `ORG-ACCOUNT`
   - Secret `SNOWFLAKE_PRIVATE_KEY` = full contents of `github_key.p8`
3. **Settings → Environments**: create `test` and `production`. On `production`, add **Required reviewers** to show an approval gate.
4. **Settings → Branches**: protect `main` and require the `dbt CI (TEST)` check to pass before merging.

## 3. Demo script

1. **Dev:** on a branch, edit a model (for example, add `avg(o.order_total) as avg_order_value` to `fct_customer_revenue`). Run `dbt build --target dev` locally or in the dbt Cloud IDE. The output lands in `DBT_DEMO_DEV.DBT_<you>_MARTS`.
2. **Test:** open a PR. `dbt CI (TEST)` builds only `state:modified+` into `DBT_DEMO_TEST.PR_<n>_*`, runs the tests, then drops the schemas. Break a test (for example, remove `'P'` from `accepted_values`) to show the PR getting blocked.
3. **Prod:** merge the PR. `dbt CD (PROD)` waits for approval, then builds `DBT_DEMO_PROD.STAGING` / `MARTS`. It uploads `manifest.json`, which the next PR uses for Slim CI.

Local dev:
```bash
pip install "dbt-snowflake~=1.9"
export SNOWFLAKE_ACCOUNT=ORG-ACCOUNT SNOWFLAKE_USER=<you> SNOWFLAKE_AUTHENTICATOR=externalbrowser
dbt build --target dev
```
(Your user needs `DBT_DEMO_DEV_ROLE`.)

## 4. Moving it to dbt Cloud

dbt Cloud reads `dbt_project.yml`, models, and macros from the same repo. It ignores `profiles.yml` and `.github/`, because connections live in dbt Cloud Environments.

1. **Account settings → Connections → Snowflake**: account `ORG-ACCOUNT`, warehouse `DBT_DEMO_WH`. Auth is key pair with user `SVC_DBT_CLOUD` and the private key from `dbt_cloud_key.p8`. Developers can use their own credentials or SSO instead.
2. **New project → Repository → GitHub**: install the dbt Cloud GitHub app and select this repo. This turns on native PR CI.
3. **Environments**:
   | dbt Cloud env | Type | Database | Role | Schema |
   |---|---|---|---|---|
   | Development | Development | `DBT_DEMO_DEV` | `DBT_DEMO_DEV_ROLE` | `dbt_<name>` (per-developer credentials) |
   | Test / CI | Deployment (Staging) | `DBT_DEMO_TEST` | `DBT_DEMO_TEST_ROLE` | `ci` |
   | Production | Deployment (Production) | `DBT_DEMO_PROD` | `DBT_DEMO_PROD_ROLE` | `analytics` |

   **Important:** the `generate_schema_name` macro checks `target.name == 'prod'`. In the Production environment, set the **Target name** field to `prod`; dbt Cloud's default is `default`. Set it to `test` in Test/CI. If you skip this, prod gets prefixed schema names.
4. **Jobs**:
   - *Prod daily*: Production env, `dbt build`, scheduled, with "Generate docs" checked.
   - *CI job*: Test/CI env, triggered on pull requests, `dbt build --select state:modified+`, deferring to *Prod daily*. dbt Cloud creates and drops its own `dbt_cloud_pr_*` schemas.
5. After dbt Cloud takes over, disable the GitHub workflows (or delete `.github/workflows`) so each PR isn't built twice. A useful talking point: GitHub Actions and dbt Cloud are two ways to run the same code against the same three environments.
