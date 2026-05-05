# CLAUDE.md — `activerecord6-redshift-adapter` (LFM fork)

> **One-line purpose:** LFM's fork of the upstream `activerecord6-redshift-adapter` Ruby gem, with a `rails7` branch that patches it to work with Rails 7 + Ruby 3.2 + pg 1.4.

## 1. Repo identity

- **Repo type:** `library` (Ruby gem; LFM fork of OSS upstream).
- **Primary language(s):** Ruby `3.2.1` (per `.ruby-version` on the `rails7` branch); the upstream gemspec on master requires `>= 2.2.2`.
- **Primary framework(s):** ActiveRecord (Rails 7+ on the `rails7` branch; Rails 6+ on `master`). Provides the `redshift_adapter` connection type for Rails to talk to AWS Redshift via the `pg` gem.
- **Lifecycle status:** `maintenance-only` — active LFM consumers (`lfm-accounts`, `dsp`, possibly `cms`) consume the `rails7` branch; `master` is left mostly stock from upstream. **8 LFM commits** on `rails7` (vs only 1 visible on `master`). Most recent change: APPS-37154 (Rails 7 upgrade).
- **Repo URL:** https://github.com/ListenFirstMedia/activerecord6-redshift-adapter
  - **Default branch:** `master` (mostly stock upstream).
  - **Branch consumers actually use:** `rails7` (per `lfm-accounts/Gemfile`, `cms/Gemfile`, and `dsp/api/Gemfile` — all of them pin `branch: 'rails7'`).
- **On-call / owners:** _<TODO: confirm with platform team. The LFM commit messages reference `APPS-36796` and `APPS-37154` (LFM JIRA tickets), suggesting the platform team owns this fork.>_
- **Slack channel:** _<TODO>_
- **Confluence / docs root:** Upstream README at https://github.com/iamdbc/activerecord6-redshift-adapter; original ancestor at https://github.com/ConsultingMD/activerecord5-redshift-adapter.

## 2. Why this repo exists

LFM's Rails apps need to query AWS Redshift via ActiveRecord. Upstream `activerecord6-redshift-adapter` (`iamdbc/activerecord6-redshift-adapter`, MIT, by Vasanth Amana) handles this for AR6, but **doesn't work with Rails 7** out of the box because Rails 7 changed the `initialize_type_map` calling convention (from a private instance method to a class method) and broke kwargs delegation in error translation.

LFM forked the gem and applied surgical patches on a dedicated **`rails7` branch** to adapt it:

- Made `initialize_type_map` a class method (on `class << self`) and added an instance shim that calls into it.
- Lazy-initialized the `@type_map` via a private `def type_map` accessor.
- Changed `super` to `super(exception, **message)` in error translation (Ruby 3 kwargs).
- Bumped Gemspec: `pg >= 0.18` → `pg >= 1.4.6`, `activerecord >= 6.0.0` → `activerecord >= 7.0.0`, Ruby `>= 2.2.2` → `>= 2.6.8`.
- Added `.ruby-version` (3.2.1).

The fork also bumps the gem's `version` from `1.1.1` → `7.1.2`. **Note: the gemspec author + email + homepage still point at the original Vasanth/drylogics — correct MIT attribution; don't change.**

It's a separate repo because LFM consumes it via `git: ... branch: 'rails7'` URLs, and the fork's `master` branch tracks upstream (mostly) so it can be merged forward when upstream eventually releases.

## 3. Where it sits in the platform

A pure Ruby gem. No runtime services.

- **Upstream services this repo calls** (runtime HTTP/RPC): _N/A — it's a gem. At runtime, code that uses this gem will reach AWS Redshift via the `pg` driver._
- **Downstream consumers** (LFM repos that bundle THIS as a gem; from `dependency_graph.json` + Gemfile inspection):
  - `lfm-accounts` — pinned to `branch: 'rails7'`.
  - `dsp` (specifically `dsp/api/Gemfile`) — pinned to `branch: 'rails7'`.
  - `cms` — pinned to `branch: 'rails7'` (also via `github_url(...)` LFM helper).
  - `lfm-etl` consumes a different fork: `pennylane-hq/activerecord7-redshift-adapter` (NOT this LFM repo). The naming similarity is misleading.
- **Library deps** (compile-time, from gemspec):
  - `pg >= 1.4.6` (rails7 branch); `pg >= 0.18` (master)
  - `activerecord >= 7.0.0` (rails7 branch); `activerecord >= 6.0.0` (master)

> Phase 1 dependency map for this repo: `~/Documents/claude-github/phase1/activerecord6-redshift-adapter.json`.

## 4. HTTP / RPC interface

_N/A — this is a Ruby gem; it exposes no HTTP routes._

It does provide one runtime extension point: `ActiveRecord::ConnectionHandling#redshift_connection(config)`, registered as the `redshift` adapter. Consuming apps activate it by setting `adapter: redshift` in their `database.yml`:

```yaml
warehouse:
  adapter: redshift
  host:     dw.listenfirst.in
  port:     5439                   # default Redshift port
  database: lfmdw
  username: <user>
  password: <password>
  encoding: utf8
```

Or via URL:
```ruby
class WarehouseRecord < ApplicationRecord
  establish_connection('redshift://username:password@host:port/database')
end
```

Then `WarehouseRecord.connection` returns an `ActiveRecord::ConnectionAdapters::RedshiftAdapter`.

## 5. APIs this repo CONSUMES

| Target service | Purpose | How it's configured | Failure mode |
|---|---|---|---|
| **AWS Redshift** (via the `pg` driver) | Connection over the Postgres wire protocol; Redshift speaks PG protocol with quirks the adapter accommodates | `database.yml` (consumer's responsibility) | `ActiveRecord::ConnectionNotEstablished` / `PG::Error` |

## 6. Tech stack details

- **Runtime versions (rails7 branch):**
  - Ruby `3.2.1` (per `.ruby-version`); gemspec `required_ruby_version >= 2.6.8`.
  - ActiveRecord `>= 7.0.0` (gemspec).
  - `pg >= 1.4.6` (gemspec).
- **Runtime versions (master branch — upstream-stock):**
  - Ruby `>= 2.2.2`.
  - ActiveRecord `>= 6.0.0`.
  - `pg >= 0.18`.
- **Package manager(s):** Bundler. `Gemfile` is one line: `gemspec`.
- **Build/test commands:**
  - Install: `bundle install`
  - Test: `bundle exec rake test` (or `rake` — default is test). Runs Minitest over `test/cases/**/*_test.rb` plus `test/cases/adapters/redshift/**/*_test.rb`.
  - The test layout was cloned from ActiveRecord's own test suite (huge — 105 YAML fixtures, 470 files total, including PostgreSQL/MySQL/Oracle adapter tests that LFM doesn't use).
- **Notable internal LFM gems / packages bundled here:** None.
- **Why we forked:**
  - Rails 7 compatibility (the dominant reason). Upstream upstream's last-known release predates Rails 7's API breakage. See §15 for the exact patch list.

### LFM patches on the `rails7` branch (8 commits ahead of `master`)

```
1651659 Merge pull request #2 from ListenFirstMedia/APPS-37154
f3e5371 updates for rails 7 upgrade
8f225a2 downgrading ruby
9095a27 upgrading rails
d0acf05 temporary downgrade
067dd72 temporary downgrade to rails6
d6b6dc9 APPS-36796 - upgrading ruby
34f604b APPS-36796 - upgrading to rails7
c608d07 incorporating Santhosh's change   ← also on master (initial fork commit)
```

The actual diff vs `master` (3 files):

1. **`activerecord6-redshift-adapter.gemspec`** — version `1.1.1` → `7.1.2`; bumped Ruby/pg/AR version requirements.
2. **`.ruby-version`** — added (`3.2.1`).
3. **`lib/active_record/connection_adapters/redshift_adapter.rb`** — 104 lines changed:
   - `initialize_type_map(type_map)` (calling the method) → `initialize_type_map(@type_map)` (using the instance variable directly).
   - Added `def initialize_type_map(m = type_map)` instance method — calls `self.class.initialize_type_map(m)` then `load_additional_types(m)`.
   - Moved `initialize_type_map` body into `class << self` as a class method (Rails 7 PostgreSQL-adapter pattern).
   - Added `private def type_map; @type_map ||= Type::HashLookupTypeMap.new; end` accessor.
   - Changed `super` → `super(exception, **message)` in `translate_exception` for Ruby 3 kwargs delegation.

## 7. Local development

### 7.1 Required services

- **AWS Redshift cluster** reachable, OR PostgreSQL (Redshift speaks the PG wire protocol; tests use Postgres).
- The full ActiveRecord test suite is vendored in `test/`, including PostgreSQL/MySQL/Oracle/SQLite/Firebird adapter tests. LFM doesn't run those — only the redshift-specific subset.

### 7.2 Required env vars

| Name | Purpose | Example | Where it's read |
|---|---|---|---|
| (none in the gem itself) | The gem reads `database.yml` config or connection URL from the consumer | — | — |
| `ARCONFIG` | Override the path to the test database config (per `test/config.rb`) | `/path/to/config.yml` | `Rakefile` / `test/config.rb` |
| `RUBY_DEBUG` | Optional — set to `1` to enable Ruby's debug output during tests | `1` | Ruby internals |

### 7.3 First-time setup

```
1. asdf install ruby 3.2.1   # or any Ruby >= 2.6.8 for the rails7 branch
2. cd activerecord6-redshift-adapter
3. git checkout rails7        # Switch to the LFM-active branch
4. bundle install
5. bundle exec rake test      # runs the Minitest suite (vendored from ActiveRecord)
```

To use locally during dev of a consumer (`lfm-accounts`/`dsp`/`cms`):

```
# In the consumer's Gemfile, replace the :git line with :path:
gem 'activerecord6-redshift-adapter', path: '../activerecord6-redshift-adapter'
```

## 8. Tests

- **How tests are organized:** Minitest under `test/`. Vendored from ActiveRecord's own test suite — includes adapter tests for Postgres, MySQL, Oracle, SQLite, Firebird, plus shared cases under `test/cases/`. LFM only runs the redshift-specific subset (per the `Rakefile`'s test_files filter).
- **How to run a single test:** `ruby -Itest test/cases/adapters/redshift/some_test.rb -n test_some_thing`
- **CI green criteria:** _<TODO: no `.github/workflows/` directory in this repo; no CI runs. Verify whether tests run anywhere — they may be run manually by whoever bumps the gem.>_
- **Coverage target / current %:** N/A.
- **Mocks vs. real services:** Tests use a real Postgres connection (the same wire protocol Redshift uses). Connection config in `test/config.yml` and `test/support/`.

## 9. Deployment

- **Where it deploys:** Nowhere directly. This is a gem. "Deployment" = pushing to the LFM `rails7` branch and having consumers `bundle update` to the new SHA.
- **How a deploy happens:** Push commits to `rails7`; consumer apps reference via `git: '…' branch: 'rails7'` in their Gemfile. Consumers pull on next `bundle install` or `bundle update`.
- **Branching model:**
  - `master` — kept close to upstream; only one commit on top (`c608d07` from the original Vasanth fork).
  - `rails7` — the LFM-active branch. **8 commits** ahead of master. Consumers pin to this branch.
  - `APPS-26902`, `APPS-37154` — feature/JIRA branches; merged into `rails7` per the merge commit message.
- **Infra-as-code:** N/A.
- **Rollback:** Consumers update their Gemfile to a previous SHA (or branch) and `bundle update activerecord6-redshift-adapter`.
- **Health-check endpoint:** N/A.

## 10. Configuration & secrets

- **Secret store:** N/A (consumers handle Redshift credentials in their own `database.yml` / env vars).
- **How config is loaded at runtime:** Standard ActiveRecord — `database.yml` or `establish_connection(config_hash | url)` from the consumer.
- **Where to find example values:** `README.md` (3 lines of YAML).
- **Feature flags:** N/A.

## 11. Data stores & state

- **AWS Redshift** — the entire purpose. Connection is via `pg` driver (no special Redshift SDK).
- **In-process state in the adapter:**
  - `@type_map` (lazy-initialized `Type::HashLookupTypeMap`) — caches OID → ActiveRecord type mappings.
  - Standard ActiveRecord connection-pool state.
  - `@local_tz` — captured at connection time via `SHOW TIME ZONE`.
- **Differences from PostgreSQL adapter** (worth knowing):
  - Redshift doesn't support all PG OIDs; the type map is curated (int2/int4/int8, float4/float8, text, varchar, char/name/bpchar aliases, bool, date, time, timestamp, timestamptz, numeric, json, jsonb, decimal).
  - Some PG features that depend on system catalogs may not work the same.
  - The `referential_integrity` module is mostly a no-op for Redshift (which doesn't enforce foreign keys).

## 12. File / directory map

```
activerecord6-redshift-adapter/
├── README.md                      — upstream README (~40 lines); short usage example
├── CLAUDE.md                      — this file
├── LICENSE                        — MIT (Heinemeier Hansson + Aoki + later contributors)
├── Gemfile                        — `source "http://rubygems.org"; gemspec` (one line)
├── Rakefile                       — Minitest test runner; `task default: :test`
├── activerecord6-redshift-adapter.gemspec  — gem metadata; on rails7 branch the version is 7.1.2 + AR/pg/ruby bumps
├── .DS_Store                      — ⚠️ macOS metadata file accidentally committed (housekeeping issue, not security)
├── .gitignore                     — standard Ruby ignores
├── lib/
│   └── active_record/connection_adapters/
│       ├── redshift_adapter.rb           — Main adapter class (637 lines on master). Registers the `:redshift` adapter; rails7 branch patches initialize_type_map, super(...,kwargs), type_map accessor.
│       └── redshift/
│           ├── array_parser.rb           — Parse Postgres array literals
│           ├── column.rb                 — Column metadata wrapper
│           ├── database_statements.rb    — INSERT/UPDATE/SELECT helpers
│           ├── oid.rb                    — OID type registry root
│           ├── oid/
│           │   ├── date_time.rb          — DateTime type
│           │   ├── decimal.rb            — Decimal type
│           │   ├── json.rb               — JSON type
│           │   ├── jsonb.rb              — JSONB type
│           │   └── type_map_initializer.rb  — initialize_type_map helper
│           ├── quoting.rb                — Identifier/value quoting (Redshift quirks)
│           ├── referential_integrity.rb  — Mostly a no-op for Redshift
│           ├── schema_definitions.rb     — Type definitions (table_definition extensions)
│           ├── schema_dumper.rb          — `db:schema:dump` support
│           ├── schema_statements.rb      — `create_table`/`add_column`/etc. (420 lines on master)
│           ├── type_metadata.rb          — Type metadata wrapper
│           └── utils.rb                  — Misc helpers (PostgresqlSQLString building)
├── test/                          — Vendored ActiveRecord test suite (470 files including 350 .rb + 105 .yml fixtures). Includes PG/MySQL/Oracle/SQLite/Firebird adapter tests that LFM doesn't run.
│   ├── cases/                     — case-by-case unit tests
│   │   ├── adapters/postgresql,mysql2,oracle,sqlite3,firebird,redshift  — adapter-specific tests
│   │   ├── associations/          — relations-style tests
│   │   ├── connection_adapters/, connection_specification/
│   │   ├── attribute_methods/, fixture_set/, migration/
│   │   ├── relation/, scoping/, validations/
│   │   ├── tasks/, coders/
│   │   └── ...
│   ├── migrations/                — sample migrations for testing migration runner
│   ├── models/                    — sample ActiveRecord models
│   ├── fixtures/                  — sample data fixtures (yml, csv)
│   ├── schema/                    — schema.rb fixtures
│   ├── support/                   — test helpers
│   ├── assets/                    — static test assets
│   └── active_record/             — extra AR test scaffolding
└── (no .github/workflows/, no CHANGELOG, no doc-src)
```

Not a monorepo — single gem at root.

## 13. Conventions & gotchas

### ⚠️ Committed credentials / housekeeping

**No committed credentials.** The repo is clean for credentials.

**One housekeeping issue:** `.DS_Store` (macOS Finder metadata) is committed at root. Add to `.gitignore` and remove. Not a security finding.

**No update to `~/Documents/claude-github/phase1/SECURITY_FINDINGS.md` is required.**

### General conventions

- **`master` ≠ what consumers use.** All known LFM consumers (`lfm-accounts`, `dsp`, `cms`) pin `branch: 'rails7'`. Read code on `rails7`, not `master`. The `rails7` branch is **8 commits** ahead of master.
- **Other LFM JIRA branches** (`APPS-26902`, `APPS-37154`) exist; `APPS-37154` was merged into `rails7` (the merge commit `1651659`). _<TODO: confirm whether `APPS-26902` is still a feature branch or is also merged.>_
- **The fork tracks an OSS lineage with multiple original authors:** Nancy Foen → Minero Aoki (`activerecord-redshift-adapter`) → ConsultingMD (AR5 fork) → iamdbc (AR6 fork) → Vasanth Amana / drylogics (current upstream HEAD) → ListenFirstMedia (this fork). The gemspec still credits the originals — correct MIT attribution.
- **Don't change the gemspec author/email/homepage.** They point at upstream Vasanth/drylogics. MIT requires keeping attribution.
- **The patches needed for Rails 7 are surgical.** The diff is 104 lines in `redshift_adapter.rb` plus a 6-line gemspec change plus `.ruby-version`. If you bump anything, keep the patch minimal — upstream may eventually release a Rails-7-compatible version, at which point we want to drop the fork.
- **Vendored ActiveRecord test suite** — `test/` includes tests for Postgres/MySQL/Oracle/SQLite/Firebird adapters that LFM doesn't run. Don't try to make them all green; the `Rakefile` filters to the redshift subset.
- **Redshift is not Postgres.** The OID type map is curated (int2/int4/int8, float4/float8, varchar/char/bpchar/name aliases, bool, date, time, timestamp/timestamptz, numeric, json, jsonb). Adding a new type that Postgres has but Redshift doesn't will silently fail at runtime.
- **`referential_integrity` is mostly no-op.** Redshift doesn't enforce foreign keys; the adapter exposes the AR API but operations are no-ops or raise.
- **No CI.** No `.github/workflows/` directory. Tests run manually. _<TODO: add a CI workflow.>_
- **The single `master` commit is from `vasanth@drylogics.com`** (initial fork). All actual LFM work is on `rails7`.

## 14. Common tasks (cookbook)

- **Run the test suite:** `bundle exec rake test`
- **Switch to the active LFM branch:** `git checkout rails7`
- **Make a patch on rails7:** `git checkout -b APPS-XXXXX-my-fix rails7`, push, open PR against `rails7`.
- **Bump the gem version pin in a consumer:** Update the consumer's `Gemfile.lock` via `bundle update activerecord6-redshift-adapter`. (Since the consumer pins by branch, this just bumps to the latest SHA on `rails7`.)
- **Test against a real Redshift cluster:** override `test/config.yml` to point at your Redshift; or run `bundle exec rake test ARCONFIG=path/to/redshift_config.yml`.
- **Sync from upstream `iamdbc/activerecord6-redshift-adapter`:**
  1. `git remote add upstream https://github.com/iamdbc/activerecord6-redshift-adapter.git`
  2. `git fetch upstream`
  3. `git checkout master && git merge upstream/master` — resolves into LFM `master`.
  4. `git checkout rails7 && git merge master` — propagates into the LFM-active branch (resolve any rails7-patch conflicts).
  5. Run tests, push.
- **Drop the fork** (when upstream releases a Rails 7-compatible version):
  1. Verify consumer (`lfm-accounts`/`dsp`/`cms`) tests pass with the new upstream gem.
  2. Update consumer Gemfiles to remove the `:git` URL and use the rubygems version.
  3. Archive this LFM repo.

## 15. Known issues / migrations in flight

- **Upstream stagnation.** `iamdbc/activerecord6-redshift-adapter` last-known release is v1.1.1; `drylogics/activerecord6-redshift-adapter` (the homepage) has had limited activity. LFM is essentially carrying the Rails 7 patch indefinitely. _<TODO: check if a Rails-7-compatible upstream now exists; if so, plan the migration.>_
- **The `pennylane-hq/activerecord7-redshift-adapter` fork** is consumed by `lfm-etl` for the same purpose — Redshift on Rails 7. Two parallel solutions to the same problem. _<TODO: consolidate. Either contribute LFM's `rails7` patches upstream to pennylane-hq, or migrate `lfm-accounts`/`dsp`/`cms` to use pennylane-hq's adapter.>_
- **Naming is misleading.** `activerecord6-redshift-adapter` v7.1.2 (the rails7 branch) is actually for AR7 — the gem's name says "6" because the schema/DDL conventions match AR6, but the runtime works against AR7. The naming will confuse future maintainers.
- **No CI.** Tests aren't run automatically on PR. _<TODO: add a `.github/workflows/ci.yml` mirroring the other LFM repos.>_
- **`.DS_Store` is committed.** Minor housekeeping bug — add to `.gitignore` and remove.
- **Some LFM commit messages contain "temporary downgrade"** (`d0acf05`, `067dd72`) — suggesting the rails7 upgrade went through several iterations including reverts. The current HEAD merges them all back into the upgrade.
- **Vendored AR test suite is huge** (470 files, 350 of them `.rb`). Most of it is unrunnable on Redshift. _<TODO: prune to just the redshift-relevant tests so the repo is smaller and easier to navigate.>_

## 16. Glossary

| Term | What it means here |
|---|---|
| `redshift adapter` | A Rails connection adapter type (`adapter: redshift` in `database.yml`) that talks to AWS Redshift over the Postgres wire protocol. |
| `OID` | Postgres object identifier — internal type ID used to look up the ActiveRecord type wrapper. The adapter maintains a curated `Type::HashLookupTypeMap` of these. |
| `type_map` | The OID → ActiveRecord type mapping. Lazy-initialized in the rails7 branch via a private accessor. |
| `RS_VALID_CONN_PARAMS` | The whitelist of `database.yml` keys the adapter forwards to `PG::Connection.connect`. |
| `rails7` branch | The LFM-active branch with 8 patches on top of upstream-from-master. **Consumers always pin this branch.** |

## 17. AI agent guidance (do's and don'ts)

**Do:**

- **Always work on the `rails7` branch** unless you're explicitly merging upstream.
- Check the LFM branch consumers reference. As of 2026-04-30: `branch: 'rails7'` for `lfm-accounts`, `dsp/api`, `cms`.
- Keep LFM patches minimal and surgical. The whole point of the fork is to be tiny.
- If you bump dependency versions (`pg`, `activerecord`, `ruby`), update the gemspec on `rails7` AND test against all consumers (`lfm-accounts`, `dsp`, `cms`).
- When pulling upstream, merge `upstream/master` → LFM `master`, then merge `master` → `rails7` (resolve conflicts).
- Add `.DS_Store` to `.gitignore` and remove the committed copy.
- Mirror the existing patch style — class-level `initialize_type_map`, instance-level shim, lazy `type_map` accessor.

**Don't:**

- Don't push directly to `rails7` without verifying consumers still compile.
- Don't change gemspec author/email/homepage — MIT attribution.
- Don't add LFM-specific business logic. The fork is for Rails-7 compat patches, nothing else.
- Don't try to make the vendored Postgres/MySQL/Oracle test suite green — they're upstream artifacts.
- Don't run `gem release` to rubygems.org. LFM consumes via git URL only.
- Don't commit `.DS_Store`, `.idea/`, or other editor metadata.
- Don't rename the gem. The Ruby module path encodes it; renaming forces every consumer to update Gemfile + Gemfile.lock.
- Don't merge the `pennylane-hq/activerecord7-redshift-adapter` fork into this one casually — it's a separate lineage.

## 18. Drift markers

- **Last verified against code:** 2026-04-30 by `Claude` (Phase 2 deep read; both `master` and `origin/rails7` branches inspected).
- **What I read in full:**
  - On `master`: `README.md`, `Gemfile`, `Rakefile`, `activerecord6-redshift-adapter.gemspec`, `LICENSE` head, `lib/active_record/connection_adapters/redshift_adapter.rb` (head), full directory listings.
  - On `origin/rails7`: `.ruby-version`, `activerecord6-redshift-adapter.gemspec`, full diff of `redshift_adapter.rb` vs master.
  - `git log` on both branches.
  - `.git/config` to confirm remote/branch pin.
- **What I did NOT read in full:**
  - 470 files in `test/` — only directory layout sampled (it's a vendored AR test suite).
  - Bodies of `lib/active_record/connection_adapters/redshift/*.rb` (column.rb, database_statements.rb, oid/*.rb, quoting.rb, referential_integrity.rb, schema_definitions.rb, schema_dumper.rb, schema_statements.rb, type_metadata.rb, utils.rb, array_parser.rb).
  - `LICENSE` past the first 5 lines (standard MIT text).
  - The `APPS-26902` branch contents (only confirmed it exists).
- **Sections most likely to drift first:** §6 (when a new patch lands on `rails7`), §15 (when upstream releases a Rails 7-compatible version, or when `lfm-etl`/the team consolidates on one Redshift-adapter fork).
- **Auto-checks (when wired up):**
  - [ ] `bundle exec rake test` green
  - [ ] `master` branch is at most a few commits behind upstream
  - [ ] `rails7` branch's redshift_adapter.rb diff vs master is bounded to `initialize_type_map` reorganization + super-kwargs + accessor
  - [ ] gemspec on `rails7` reflects current Ruby/Rails/pg minimums
  - [ ] no `.DS_Store` or other editor metadata committed
  - [ ] no committed credentials in tracked files

---
