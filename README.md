<div align="center">

# 🛡️ Lect &amp; Nect

### Smart Visitor &amp; Staff Management System

**Gate passes, OTP-verified check-ins, staff attendance and role-based access control —
in one Rails + Next.js stack.**

[![CI](https://github.com/workmarathon01/digital-ember-vIms-/actions/workflows/ci.yml/badge.svg)](https://github.com/workmarathon01/digital-ember-vIms-/actions/workflows/ci.yml)
[![Dependabot](https://img.shields.io/badge/dependabot-enabled-0f766e?logo=dependabot&logoColor=white)](https://github.com/workmarathon01/digital-ember-vIms-/network/updates)
[![Ruby](https://img.shields.io/badge/Ruby-3.2.2-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.1.3-CC0000?logo=rails&logoColor=white)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Next.js](https://img.shields.io/badge/Next.js-16.3-000000?logo=next.js&logoColor=white)](https://nextjs.org/)
[![React](https://img.shields.io/badge/React-19.2-087EA4?logo=react&logoColor=white)](https://react.dev/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-4.0-06B6D4?logo=tailwindcss&logoColor=white)](https://tailwindcss.com/)
[![Pundit](https://img.shields.io/badge/Pundit-2.4-3B82F6?logo=ruby&logoColor=white)](https://github.com/varvet/pundit)
[![Pagy](https://img.shields.io/badge/Pagy-9.0-06B6D4?logo=ruby&logoColor=white)](https://github.com/ddnexus/pagy)
[![JWT](https://img.shields.io/badge/JWT-2.10-000000?logo=jsonwebtokens&logoColor=white)](https://github.com/jwt/ruby-jwt)
[![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Kamal](https://img.shields.io/badge/Kamal-2-3DDC84?logo=docker&logoColor=white)](https://kamal-deploy.org/)
[![License](https://img.shields.io/badge/license-add%20one-94a3b8?logo=opensourceinitiative&logoColor=white)](#-license)

</div>

---

## 📖 Table of Contents

- [🎯 About](#-about)
- [✨ Features](#-features)
- [🧱 Tech Stack](#-tech-stack)
- [🏗️ Architecture](#%EF%B8%8F-architecture)
- [🔐 Authentication](#-authentication)
- [🛡️ Roles &amp; Permissions](#%EF%B8%8F-roles--permissions)
- [🗄️ Data Model](#%EF%B8%8F-data-model)
- [🌐 API Reference](#-api-reference)
- [🚀 Getting Started](#-getting-started)
- [⚛️ Frontend Setup](#%EF%B8%8F-frontend-setup)
- [🔑 Environment Variables](#-environment-variables)
- [🧪 Testing &amp; Quality](#-testing--quality)
- [📦 Deployment](#-deployment)
- [🔒 Security Notes](#-security-notes)
- [🗺️ Roadmap](#%EF%B8%8F-roadmap)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

---

## 🎯 About

**Lect &amp; Nect** is a gate-management platform for societies, campuses and corporate campuses.
It replaces the paper register at the security desk with a digital workflow:

| | |
|---|---|
| 🚶 **Visitor lifecycle** | Pre-register a guest → system issues a pass code + QR token → OTP verification at the desk → check-in → check-out → archive |
| 👷 **Staff lifecycle** | Create a staff record → approve/reject → schedule working hours → punch in / punch out with IP tracking |
| 🕵️ **Security posture** | Every create / update / destroy / sign-in is written to an immutable-ish audit trail with actor, IP and user agent |
| 🔐 **Access control** | Database-driven RBAC — 4 system roles, 5 resources, 25 granular actions, editable from the UI |

The backend is a **Rails 8.1 API + server-rendered admin console**. The frontend is a
**Next.js 16 App Router SPA** that talks to the same JSON API using JWT bearer tokens.

> 💡 The name is a nod to **connection** — linking visitors, staff and the people who
> authorise their access.

---

## ✨ Features

### 🚪 Visitor Management
- ✅ Pre-registration with purpose, host, vehicle number, expected date/time and goods-inwards flags
- ✅ Auto-generated **pass code** (`PASS-XXXXXXXX`) and HMAC-digested **QR token**
- ✅ Configurable pass validity window (defaults to 24 hours)
- ✅ 🔐 **6-digit OTP** verification before check-in — 10-minute TTL, max 5 generation attempts
- ✅ Check-in / check-out state machine (`visitor_in_out` = `IN` / `OUT`)
- ✅ Soft-delete archival instead of hard delete (`is_deleted`)
- ✅ Search across name, contact, purpose, pass code and vehicle number

### 👷 Staff Management
- ✅ Auto-generated **staff code** (`STF-XXXXXX`) with HMAC-digested QR token
- ✅ Approval workflow — `Pending` → `Approved` / `Rejected` / `Suspended`
- ✅ 🕐 **Punch in / punch out** attendance with automatic duration calculation
- ✅ Per-staff weekly working schedule stored as JSONB (`selected`, `start_time`, `end_time`)
- ✅ Geo coordinates, vendor, site and unit assignment
- ✅ Search by name, email, mobile, staff code or work type

### 🔐 Access Control &amp; Security
- ✅ **Pundit** policies on every controller action
- ✅ Role builder UI with a live permission matrix (`resource:action` checkboxes)
- ✅ `admin` role is a super-user — bypasses all permission checks
- ✅ 🔒 **Account lockout** — 5 failed attempts ⇒ locked for 30 minutes
- ✅ Admin-forced lock / unlock with a dedicated audit entry
- ✅ Admin can **deactivate** (never destroy) user accounts
- ✅ Session-recording of sign-in count, current/last IP and timestamps

### 🧾 Audit &amp; Observability
- ✅ `Auditable` concern auto-logs `create` / `update` / `destroy` after commit
- ✅ Stores JSONB `details` (the `previous_changes` diff), IP address and user agent
- ✅ Explicit entries for `sign_in`, `sign_out`, `lock`, `unlock`
- ✅ Filterable, paginated activity log UI + JSON endpoint
- ✅ Health check endpoint at `GET /up` for load balancers

### 🎨 Interface
- ✅ Server-rendered Rails console (Hotwire Turbo + Stimulus, importmap — no bundler needed)
- ✅ Next.js SPA with sidebar navigation, dark-navy design system and `lucide-react` icons
- ✅ JSON API for every index / show / create action (Jbuilder)
- ✅ Pagy pagination everywhere (25/page for users &amp; staff, 10/page for visitors, 50/page for audit logs)
- ✅ Responsive, framework-agnostic plain CSS on the Rails side — zero CSS build step

---

## 🧱 Tech Stack

### ⚙️ Backend — `lect_and_nect/`

| Layer | Choice | Purpose |
|---|---|---|
| 💎 Ruby | `3.2.2` | Runtime (`.ruby-version`, `.tool-versions`) |
| 🚂 Rails | `8.1.3` | Framework |
| 🐘 PostgreSQL | `pg ~> 1.5` | Primary datastore |
| 🧬 Active Record | 8.1 | ORM + `normalizes`, `has_secure_password` |
| 🛡️ Pundit | `~> 2.4` | Object-oriented authorization policies |
| 🔑 BCrypt | `~> 3.1` | Password hashing |
| 🪙 JWT | `~> 2.10` | Stateless access + refresh tokens |
| 📄 Jbuilder | bundled | JSON views |
| 🔀 Pagy | `~> 9.0` | Pagination (backend + frontend) |
| 🌶️ rack-cors | `~> 2.0` | CORS for the Next.js app |
| 🧵 Puma + Thruster | `>= 5.0` | App server + HTTP caching / compression |
| 🎨 Propshaft | bundled | Asset pipeline |
| 🗺️ Importmap | bundled | ESM JS — Turbo, Stimulus (no Node required) |
| ⚡ Hotwire | `turbo-rails`, `stimulus-rails` | SPA-like navigation + JS framework |
| 🧹 Solid Queue / Cache / Cable | bundled | Background jobs, cache, Action Cable — all Postgres-backed |
| 🚀 Bootsnap | bundled | Faster boot |
| 🐳 Kamal + Docker | bundled | Zero-downtime deploys |
| 📦 Active Storage | `image_processing ~> 1.2` | File & variant storage |

### 🎨 Frontend — `frontend/`

| Layer | Choice | Purpose |
|---|---|---|
| ⚛️ Next.js | `16.3.6` | App Router, React Server Components |
| ⚛️ React | `19.2.8` | UI runtime |
| 🎨 Tailwind CSS | `^4.0` | Utility-first styling via `@tailwindcss/postcss` |
| 🧩 lucide-react | `^1.47.0` | Icon set |
| 🔷 TypeScript | `^5` | Types for API payloads |
| 🧹 ESLint | `^9` | Linting |

---

## 🏗️ Architecture

```
PerSonalProject/
├── lect_and_nect/          # 🚂 Rails 8.1 API + admin console
│   ├── app/
│   │   ├── controllers/    # 8 controllers, dual HTML/JSON responders
│   │   ├── models/         # User, Staff, Visitor, Role, Permission,
│   │   │                   #   StaffAttendance, AuditLog + Auditable concern
│   │   ├── policies/       # Pundit: one policy per resource
│   │   ├── services/       # JsonWebToken
│   │   ├── views/          # ERB console + .jbuilder JSON views
│   │   ├── javascript/     # Importmap entrypoint + Stimulus controllers
│   │   └── assets/         # Propshaft (hand-written CSS design tokens)
│   ├── bin/                # rails, dev, setup, ci, kamal, thruster, jobs…
│   ├── config/             # database, cache, queue, cable, deploy, ci
│   ├── db/                 # schema.rb + 2 migrations
│   └── test/               # model, policy and controller tests
│
└── frontend/               # ⚛️ Next.js 16 SPA (port 3002)
    └── src/
        ├── app/            # (app)/* routes + login landing
        ├── components/     # sidebar, kiosk panel, UI primitives, icons
        └── lib/            # api.ts (fetch + token refresh), auth-context.tsx
```

### 🔁 Request flow

```
Browser ──▶ Next.js :3002 ──▶ Authorization: Bearer <access_token>
                                        │
                                        ▼
                              Rails :3000 ──▶ ApplicationController
                                                   │
                              ┌────────────────────┴────────────────────┐
                              │                                         │
                      JWT path (JSON)                        Cookie path (HTML)
                    decode_access → Current.user          session[:user_id] → User
                              │                                         │
                              └──────────────▶ Pundit authorize ─────────┘
                                                   │
                                    ┌──────────────┴──────────────┐
                                 Controller                    Auditable
                                    │                         (after_commit)
                              Jbuilder / ERB                   ▼
                                                          audit_logs
```

---

## 🔐 Authentication

The app supports **two authentication strategies** simultaneously, chosen by request format:

| | 🧑‍💻 HTML console | 📱 JSON API (Next.js) |
|---|---|---|
| **Mechanism** | Rails signed session cookie | `Authorization: Bearer <jwt>` |
| **Handled by** | `session[:user_id]` | `JsonWebToken.decode_access` |
| **CSRF** | ✅ Required | ⏭️ Skipped (`skip_before_action :verify_authenticity_token`) |
| **Unauthorised** | `302 → /session/new` | `401` + `WWW-Authenticate` header |
| **Forbidden** | `302 → /` with alert | `403` JSON error |

### 🪙 Token details

| Property | Value |
|---|---|
| Algorithm | `HS256` |
| Issuer | `lect_and_nect` |
| Access TTL | ⏱️ **15 minutes** |
| Refresh TTL | 📆 **30 days** |
| Claims | `sub` (user id), `typ` (`access`/`refresh`), `iss`, `jti`, `iat`, `exp` |
| Secret resolution | `ENV["JWT_SECRET"]` → `credentials.jwt_secret` → `secret_key_base` |

### 🔄 Token refresh

```bash
curl -X POST http://localhost:3000/session/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"<refresh_token>"}'
```

Returns a **fresh access + refresh pair**. The Next.js client (`src/lib/api.ts`) does this
**automatically and transparently** — on any `401` it refreshes once and replays the request.

### 🔑 Sign-in

```bash
curl -X POST http://localhost:3000/session.json \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@lect-and-nect.test","password":"ChangeMeNow!2026"}'
```

```json
{
  "token_type": "Bearer",
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "expires_in": 900,
  "user": { "id": 1, "email": "admin@lect-and-nect.test", "full_name": "System Admin", ... }
}
```

> 🚨 **Lockout:** 5 consecutive failures ⇒ `423 Locked` with `account_locked` for **30 minutes**.

---

## 🛡️ Roles &amp; Permissions

### 🎭 System roles

| Key | Name | Power | Purpose |
|---|---|---|---|
| 👑 `admin` | System Administrator | 100 | Unrestricted — bypasses every permission check |
| 🛡️ `security` | Security Desk | 60 | Manages visitor passes and on-site staff |
| 🔧 `staff` | Operations Staff | 30 | Everyday visitor check-in and own attendance |
| 🏠 `resident` | Resident | 10 | Self-service visitor invites |

### 🔢 Available actions per resource

| Resource | Actions |
|---|---|
| `users` | `read` `create` `update` `deactivate` `lock` `assign_roles` |
| `visitors` | `read` `create` `update` `destroy` `check_in` `check_out` `generate_otp` `export` |
| `staffs` | `read` `create` `update` `destroy` `approve` `suspend` `attendance` `export` |
| `roles` | `read` `create` `update` `destroy` `permissions` |
| `audit_logs` | `read` `export` |

### ✅ Seeded permission matrix

| | `admin` | `security` | `staff` | `resident` |
|---|:---:|:---:|:---:|:---:|
| **users** `read` | ✅ | ✅ | — | — |
| **users** everything else | ✅ | — | — | — |
| **visitors** `read` | ✅ | ✅ | ✅ | ✅ |
| **visitors** `create` | ✅ | ✅ | — | ✅ |
| **visitors** `update` `destroy` | ✅ | ✅ | — | — |
| **visitors** `check_in` `check_out` | ✅ | ✅ | ✅ | — |
| **visitors** `generate_otp` `export` | ✅ | ✅ | — | — |
| **staffs** `read` | ✅ | ✅ | ✅ | — |
| **staffs** `create` `update` `destroy` | ✅ | ✅ | — | — |
| **staffs** `approve` `suspend` `attendance` `export` | ✅ | ✅ | — | — |
| **roles** all | ✅ | — | — | — |
| **audit_logs** `read` | ✅ | ✅ | — | — |

> 👑 `admin` is a **super-user** — every cell is effectively ✅ because `Role#can?` short-circuits.

### 🧭 Policy resolution

```ruby
# app/policies/user_policy.rb
def show?  = super || record == user   # you can always view yourself
def update? = super || record == user  # you can always edit yourself
def destroy? = permission?(:deactivate) # never hard-delete — soft deactivate

# app/controllers/users_controller.rb
def update
  attrs.delete(:role_id) unless current_user.can?(:users, :assign_roles) # privilege escalation guard
end
```

The dashboard is also permission-aware — metrics you lack `read` for simply don't render,
and `recent_activity` is hidden without `audit_logs:read`.

---

## 🗄️ Data Model

```
┌────────────┐         ┌──────────────────┐
│    roles   │ 1──────n│   permissions    │
│────────────│         │──────────────────│
│ id         │         │ id               │
│ key  (uniq)│         │ role_id (fk)     │
│ name       │         │ resource         │
│ description│         │ action           │
│ is_system  │         │ UNIQUE(role_id,  │
│ active     │         │   resource,      │
│ power_level│         │   action)        │
└─────┬──────┘         └──────────────────┘
      │ 1
      │
      │ n
┌─────┴──────────┐              ┌──────────────────┐
│     users      │              │  staff_attendances│
│────────────────│         ┌───▶│──────────────────│
│ id             │         │    │ id               │
│ email  (uniq)  │         │ n  │ staff_id (fk)    │
│ password_digest│        ┌───┴───│ punched_in_at    │
│ firstname      │        │       │ punched_out_at   │
│ lastname       │        │ ┌─────│ ip_address       │
│ mobile         │        │ │     └──────────────────┘
│ role_id (fk)   │        │ │
│ active         │        │ │
│ failed_attempts│        │ │   ┌──────────────┐
│ locked_at      │        │ │ n │    staffs    │
│ lock_token     │        │ └──▶│──────────────│
│ otp_digest     │        │     │ id           │
│ sign_in_count  │        │     │ staff_id(uniq)│
│ current/last   │        │     │ firstname    │
│  _sign_in_ip   │        │     │ lastname     │
│ + ~80 columns  │        │     │ mobile_no    │
└─────┬──────────┘        │     │ status_type  │
      │                   │     │ status       │
      │ 1                 │     │ staff_in_out │
      │                   │     │ work_type    │
      │ n                 │     │ site_id      │
┌─────┴──────────┐        │     │ working_     │
│    visitors    │        │     │  schedule    │
│────────────────│        │     │  (jsonb)     │
│ id             │        │     │ qr_token_    │
│ name           │        │     │  digest      │
│ contact_no     │        │     └──────────────┘
│ pass_code(uniq)│        │
│ start_pass     │        │       ┌──────────────┐
│ end_pass       │        └──────▶│  audit_logs  │◀──┐
│ visitor_in_out │                │──────────────│   │ polymorphic
│ otp_digest     │                │ id           │   │ actor
│ otp_attempts   │                │ action       │   │
│ verified       │                │ actor_type   │   │
│ qr_token_digest│                │ actor_id     │───┘
│ is_deleted     │                │ resource_type│
└────────────────┘                │ resource_id  │
                                 │ details jsonb│
                                 │ ip_address   │
                                 │ user_agent   │
                                 └──────────────┘
```

| Table | Rows | Key columns |
|---|---|---|
| 👥 `users` | Login accounts | `email`*, `password_digest`, `role_id`, `active`, `failed_attempts`, `locked_at`, `lock_token`, `otp_digest`, `sign_in_count`, `current_sign_in_ip`, `last_sign_in_ip` |
| 🛡️ `roles` | 4 seeded | `key`*, `name`, `description`, `power_level`, `is_system`, `active` |
| 🔑 `permissions` | 22 seeded | `role_id`, `resource`, `action` — unique triple |
| 👷 `staffs` | Staff directory | `staff_id`*, `mobile_no`+`site_id`*, `status_type`, `status`, `staff_in_out`, `working_schedule`, `qr_token_digest` |
| 🕐 `staff_attendances` | Punch records | `staff_id`, `punched_in_at`, `punched_out_at`, `ip_address` |
| 🚶 `visitors` | Pass registry | `pass_code`*, `contact_no`, `visitor_in_out`, `start_pass`, `end_pass`, `otp_digest`, `otp_attempts`, `verified`, `qr_token_digest`, `is_deleted` |
| 📋 `audit_logs` | Activity trail | `action`, `actor_type`+`actor_id`, `resource_type`+`resource_id`, `details` jsonb, `ip_address`, `user_agent` |

<sub>`*` = unique index · `+` = composite unique index</sub>

### ➕ Solid backends

Rails 8 runs queues, cache and Action Cable on Postgres too — four databases in production:

| `POSTGRES_DB` | `POSTGRES_CACHE_DB` | `POSTGRES_QUEUE_DB` | `POSTGRES_CABLE_DB` |
|---|---|---|---|
| `lect_and_nect_production` | `…_production_cache` | `…_production_queue` | `…_production_cable` |

---

## 🌐 API Reference

All endpoints below respond to **both** HTML and JSON. Append `.json` (or send
`Accept: application/json`) for machine-readable output.

### 🔓 Public

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/up` | 🩺 Health check — `200` if the app boots cleanly |
| `GET` | `/session/new` | 🧑‍💻 Sign-in page |
| `POST` | `/session` · `/session.json` | 🔑 Sign in — HTML session or token pair |
| `POST` | `/session/refresh` | 🔄 Exchange refresh token for a new pair |
| `DELETE` | `/session` | 🚪 Sign out + audit entry |

### 🔒 Authenticated

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/` | 📊 Dashboard metrics + recent activity |
| **Users** | | |
| `GET` `POST` | `/users` | 📋 List (filter `?q=`, `?role_id=`) / create |
| `GET` `PATCH` `DELETE` | `/users/:id` | 👤 Show / update / **deactivate** |
| `POST` | `/users/:id/lock` | 🔒 Force lockout |
| `POST` | `/users/:id/unlock` | 🔓 Clear lockout |
| **Visitors** | | |
| `GET` `POST` | `/visitors` | 📋 List (filter `?q=`, `?visit_type=`, `?in_out=`) / create |
| `GET` `PATCH` `DELETE` | `/visitors/:id` | 🚶 Show / update / archive |
| `POST` | `/visitors/:id/generate_otp` | 🔐 Issue 6-digit OTP (shown once) |
| `POST` | `/visitors/:id/check_in` | ✅ Check in — requires `otp` param |
| `POST` | `/visitors/:id/check_out` | 👋 Check out |
| **Staff** | | |
| `GET` `POST` | `/staffs` | 📋 List (filter `?q=`, `?status=`, `?only_approved=1`) / create |
| `GET` `PATCH` `DELETE` | `/staffs/:id` | 👷 Show / update / suspend |
| `POST` | `/staffs/:id/approve` | ✅ Approve record |
| `POST` | `/staffs/:id/suspend` | ⏸️ Suspend record |
| `POST` | `/staffs/:id/punch_in` | 🕐 Start attendance shift |
| `POST` | `/staffs/:id/punch_out` | 🕐 End shift + compute duration |
| **Roles** | | |
| `GET` `POST` | `/roles` | 🎭 List / create with nested permissions |
| `GET` `PATCH` `DELETE` | `/roles/:id` | 🎭 Show + members / update / delete |
| **Audit** | | |
| `GET` | `/audit_logs` | 📋 Activity log — filter `?actor_id=`, `?resource_type=`, `?action=` |

### 📦 Error envelope

```json
{ "error": { "code": "token_expired", "message": "Access token has expired. Refresh it and retry." } }
```

Codes: `unauthorized` · `invalid_token` · `token_expired` · `invalid_credentials` ·
`account_locked` · `forbidden` · `validation_failed` · `unknown`

### ✏️ Example — issue a visitor pass

```bash
curl -X POST http://localhost:3000/visitors.json \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"visitor":{"name":"Aarav Sharma","contact_no":"9876543210",
       "purpose":"Vendor delivery","visit_type":"Guest","site_id":1}}'
```

```bash
# 🔐 Generate OTP → returned in flash / shown once on the page
curl -X POST http://localhost:3000/visitors/1/generate_otp -H "Authorization: Bearer $ACCESS_TOKEN"

# ✅ Check in with the OTP
curl -X POST http://localhost:3000/visitors/1/check_in \
  -H "Authorization: Bearer $ACCESS_TOKEN" -d "otp=123456"
```

---

## 🚀 Getting Started

### 📋 Prerequisites

| Tool | Version | Check |
|---|---|---|
| 💎 Ruby | `3.2.2` | `ruby -v` |
| 📦 Bundler | `2.x` | `bundle -v` |
| 🐘 PostgreSQL | `14+` running | `pg_isready` |
| 🧵 Node.js | `20+` *(frontend only)* | `node -v` |
| 🐳 Docker | *optional*, for deploys | `docker -v` |

> 💡 No Node.js needed for the Rails app — importmap ships Turbo and Stimulus as vendored ESM.
> Use [asdf](https://asdf-vm.com/) or [rbenv](https://github.com/rbenv/rbenv) if Ruby isn't pinned.

### ⚡ One-command setup

```bash
git clone https://github.com/workmarathon01/digital-ember-vIms-.git
cd lect_and_nect

bin/setup              # bundle install + db:prepare + log clear + boot server
```

<details>
<summary><b>🐢 Manual setup</b></summary>

```bash
# 1️⃣  Install gems
bundle install

# 2️⃣  Point at your database (defaults shown)
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432

# 3️⃣  Create, migrate and seed
bin/rails db:prepare
bin/rails db:seed

# 4️⃣  Boot
bin/rails server        # → http://localhost:3000
```

</details>

### 🌱 Seed data

`bin/rails db:seed` provisions the RBAC matrix, two demo logins and sample records:

| 👤 Email | 🔑 Password | 🎭 Role |
|---|---|---|
| `admin@lect-and-nect.test` | `ChangeMeNow!2026` | 👑 admin |
| `security@lect-and-nect.test` | `ChangeMeNow!2026` | 🛡️ security |

Plus one demo visitor (`9000000001`) and one demo staff member (`9000000002`, *Meera Staff*).

> ⚠️ **Change these immediately outside local development.**

### 🏃 Running

```bash
bin/rails server        # 🚂 Rails on http://localhost:3000
bin/dev                 # 🧹 Rails + CSS watcher + log tailer
bin/jobs                # ⚙️ Solid Queue worker (separate process)
bin/rails console      # 💬 IRB with awesome_print loaded
```

Open **<http://localhost:3000>** and sign in with a seeded account.
The sidebar only renders links your role can actually reach — try signing in as
`resident` to see the RBAC in action.

### 🔄 Reset everything

```bash
bin/rails db:reset        # drop → create → load schema → seed
bin/setup --reset         # same, via the setup script
```

---

## ⚛️ Frontend Setup

```bash
cd frontend
npm install
cp .env.example .env.local     # optional — defaults to http://localhost:3000
npm run dev                    # → http://localhost:3002
```

| Script | Action |
|---|---|
| `npm run dev` | 🛠️ Dev server on **:3002** (chosen to avoid clashing with Rails on :3000) |
| `npm run build` | 📦 Production build |
| `npm run start` | ▶️ Serve the production build |
| `npm run lint` | 🔍 ESLint |

### 🔗 Backend connection

`NEXT_PUBLIC_API_URL` points the SPA at the Rails API. CORS is pre-authorised for
`http://localhost:3002` via `config/initializers/cors.rb` — override at deploy time with
`CORS_ALLOWED_ORIGINS`.

### 🗺️ Pages

| Route | Purpose | Status |
|---|---|---|
| `/` | 🏠 Landing page | ✅ Live |
| `/login` | 🔑 Sign-in | ✅ Wired to API |
| `/dashboard` | 📊 Metrics overview | ✅ Wired to API |
| `/visitors` | 🚶 Visitor registry | ✅ Wired to API |
| `/staffs` | 👷 Staff directory | ✅ Wired to API |
| `/users` | 👥 User management | ✅ Wired to API |
| `/kiosk` | 🖥️ Self-service kiosk | 🚧 UI shell |
| `/reports` | 📈 Analytics | 🚧 UI shell |
| `/settings` | ⚙️ Preferences | 🚧 Profile only |

### 🔐 Client-side auth

Tokens live in `localStorage` under `visitrack.*`:

```
visitrack.access_token   visitrack.refresh_token   visitrack.user
```

`src/lib/api.ts` attaches the bearer header, and on a `401` calls `/session/refresh`
**once** before replaying — so a 15-minute access TTL is invisible to the user.

---

## 🔑 Environment Variables

| Variable | 📌 Used in | 🎯 Purpose | 🏷️ Default |
|---|---|---|---|
| `POSTGRES_USER` | `database.yml` | DB username | `akshay` |
| `POSTGRES_PASSWORD` | `database.yml` | DB password | `akshay@1A` |
| `POSTGRES_HOST` | `database.yml` | DB host | `localhost` |
| `POSTGRES_PORT` | `database.yml` | DB port | `5432` |
| `POSTGRES_DB` | `database.yml` | Primary database | `lect_and_nect_development` |
| `POSTGRES_TEST_DB` | `database.yml` | Test database | `lect_and_nect_test` |
| `POSTGRES_CACHE_DB` | `database.yml` | Solid Cache DB (prod) | `lect_and_nect_production_cache` |
| `POSTGRES_QUEUE_DB` | `database.yml` | Solid Queue DB (prod) | `lect_and_nect_production_queue` |
| `POSTGRES_CABLE_DB` | `database.yml` | Solid Cable DB (prod) | `lect_and_nect_production_cable` |
| `DB_HOST` | `database.yml` | Prod DB host override | `localhost` |
| `JWT_SECRET` | `json_web_token.rb` | 🔑 HS256 signing key | falls back to credentials |
| `CORS_ALLOWED_ORIGINS` | `cors.rb` | Comma-separated origins | `http://localhost:3002,http://127.0.0.1:3002` |
| `RAILS_MASTER_KEY` | everywhere | 🔐 Credentials encryption | — |
| `RAILS_MAX_THREADS` | `database.yml`, `puma.rb` | Pool size | `5` |
| `JOB_CONCURRENCY` | `queue.yml` | Solid Queue processes | `1` |
| `WEB_CONCURRENCY` | Puma | Web processes | `1` |
| `RAILS_LOG_LEVEL` | Rails | Log verbosity | `info` |
| `SOLID_QUEUE_IN_PUMA` | `deploy.yml` | Run workers inside Puma | `true` |
| `NEXT_PUBLIC_API_URL` | `frontend` | Rails API base URL | `http://localhost:3000` |

> 🔐 Credentials live in `config/credentials.yml.enc`. Set `JWT_SECRET` explicitly in production —
> otherwise tokens fall back to `secret_key_base`.

---

## 🧪 Testing &amp; Quality

### 🏃 Test suite

```bash
bin/rails test                 # 🧪 everything
bin/rails test test/models     # 🧬 models only
bin/rails test:system          # 🖥️ Capybara + Selenium
RAILS_ENV=test bin/rails db:test:prepare test
```

| Suite | Coverage |
|---|---|
| 🧬 `test/models` | `user_test` · `staff_test` · `visitor_test` · `role_test` |
| 🛡️ `test/policies` | `user_policy_test` |
| 🎛️ `test/controllers` | `access_control_test` · `json_authentication_test` · `json_rendering_test` |

### 🔍 Linters &amp; scanners

```bash
bin/rubocop                # 💎 style — rubocop-rails-omakase
bin/brakeman --no-pager    # 🛡️ static analysis for Rails vulns
bin/bundler-audit          # 📦 known CVEs in gems
bin/importmap audit        # 📦 known CVEs in pinned JS
```

### 🧭 All-in-one CI

```bash
bin/ci                     # 🧭 setup → rubocop → audits → brakeman → tests → seeds
```

### ☁️ GitHub Actions

`.github/workflows/ci.yml` runs on every PR and push to `main`:

| Job | 📌 Steps |
|---|---|
| 🔐 `scan_ruby` | `brakeman` + `bundler-audit` |
| 🌐 `scan_js` | `importmap audit` |
| 💎 `lint` | `rubocop -f github` (with cache) |
| 🧪 `test` | `db:test:prepare test` |
| 🖥️ `system-test` | `test:system` + uploads failure screenshots |

🔄 **Dependabot** watches `bundler` and `github-actions` weekly (max 10 open PRs each).

---

## 📦 Deployment

### 🐳 Docker

Multi-stage build, non-root `rails:rails` user, jemalloc enabled:

```bash
docker build -t lect_and_nect .
docker run -d -p 80:80 \
  -e RAILS_MASTER_KEY=$(cat config/master.key) \
  -e POSTGRES_HOST=db-host \
  --name lect_and_nect lect_and_nect
```

### 🚢 Kamal 2

```bash
bin/kamal setup                  # 🔧 first-time host prep
bin/kamal build                  # 📦 build image on the remote arch
bin/kamal deploy                 # 🚀 rolling deploy
```

| Alias | 📌 Runs |
|---|---|
| `bin/kamal console` | 💬 `rails console` inside the container |
| `bin/kamal shell` | 🐚 bash inside the container |
| `bin/kamal logs` | 📜 tail production logs |
| `bin/kamal dbc` | 🗄️ `psql` with the password prefilled |

**Topology:** service `lect_and_nect` → web role on `192.168.0.1` → Thruster on port 80.
Secrets are injected from `.kamal/secrets` (which reads `config/master.key`).
Active Storage persists on the `lect_and_nect_storage` volume at `/rails/storage`.

### ⚙️ Production checklist

- [ ] 🔄 Point `config/deploy.yml` `servers.web` at the real host
- [ ] 🐘 Provision Postgres + create the **four** databases
- [ ] 🔐 Set `JWT_SECRET`, `POSTGRES_*`, `CORS_ALLOWED_ORIGINS` via `.kamal/secrets`
- [ ] 🔒 Rotate every seeded password; delete the demo visitor and staff records
- [ ] 🔒 Move `POSTGRES_USER`/`POSTGRES_PASSWORD` defaults out of `config/database.yml`
- [ ] 📡 Add `proxy: ssl: true` + `assume_ssl`/`force_ssl` for HTTPS
- [ ] 👥 Create real role assignments; demote the admin account if shared

---

## 🔒 Security Notes

| Control | Implementation |
|---|---|
| 🔑 Password hashing | BCrypt via `has_secure_password` (never plaintext, never logged) |
| 🛡️ Brute force | 5 attempts ⇒ 30-minute lockout; `lock_token` for revocation |
| 🪙 Stateless tokens | HS256 JWT, short 15-min access TTL, separate refresh token, `typ` claim prevents token-substitution attacks |
| 🕵️ Constant-time compare | `ActiveSupport::SecurityUtils.secure_compare` for every OTP check |
| 🔒 Secrets at rest | OTP and QR tokens stored as HMAC-SHA256 **digests**, never raw values |
| ⏱️ OTP expiry | 10-minute TTL; digest nulled immediately after successful verification |
| 🚫 CSRF | Enforced for HTML; intentionally skipped only for `format.json` bearer clients |
| 🧹 Parameter filtering | `config/initializers/filter_parameter_logging.rb` redacts secrets from logs |
| 🎭 Least privilege | Per-action Pundit policies + a guard that strips `role_id` unless `users:assign_roles` |
| 🗑️ Soft deletes | Users are deactivated and visitors archived — records are never destroyed |
| 📜 Full audit trail | Every mutation recorded with actor, IP and user agent |
| 🧱 Modern browsers only | `allow_browser versions: :modern` |
| 🔍 Continuous scanning | Brakeman + bundler-audit + importmap audit in CI |
| 🕵️ SQL | Active Record parameter binding everywhere; `ILIKE` search uses bound params |

---

## 🗺️ Roadmap

- [ ] 🖨️ **QR pass rendering** — issue a printable/SVG pass from the stored token digest
- [ ] 🚦 **Hardware sync** — `lotus_hardware_synced` / `is_synced_with_hardware` flags are placeholders
- [ ] 🖥️ **Wire up kiosk mode** to the real pass-issuing API
- [ ] 📈 **Reports** — footfall, peak hours, average visit duration
- [ ] 📤 **CSV export** — `visitors:export` and `staffs:export` permissions already exist
- [ ] 📱 **PWA** — manifest and service-worker views are present but not linked in `routes.rb`
- [ ] 🔔 **Email / SMS OTP delivery** — currently surfaced once in the UI
- [ ] 🌍 **Multisite / multisociety tenancy** on the existing `site_id` columns
- [ ] 🧪 **System test coverage** for the visitor and staff workflows

---

## 🤝 Contributing

1. 🍴 Fork the repository
2. 🌿 Create a branch — `git checkout -b feat/visitor-qr-pass`
3. ✍️ Keep it green: `bin/ci`
4. 💎 Match the house style — `bin/rubocop -a`
5. 📤 Open a PR against `main`

**Commit conventions** follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(visitors): add printable QR pass
fix(auth): refresh token before replaying on 401
chore(deps): bump rails from 8.1.3 to 8.1.4
docs(readme): document the audit log envelope
```

---

## 📄 License

This project is **private / unlicensed**. Add a `LICENSE` file before publishing —
[MIT](https://opensource.org/licenses/MIT) and
[AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.en.html) are the usual choices for
gate-management software.

---

<div align="center">

### 🛡️ Lect &amp; Nect

**Smart Visitor &amp; Staff Management System**

Made with 💎 Ruby, 🚂 Rails and ⚛️ Next.js

[![Rails](https://img.shields.io/badge/Rails-8.1.3-CC0000?logo=rails&logoColor=white)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Next.js](https://img.shields.io/badge/Next.js-16.3-000000?logo=next.js&logoColor=white)](https://nextjs.org/)
[![CI](https://github.com/workmarathon01/digital-ember-vIms-/actions/workflows/ci.yml/badge.svg)](https://github.com/workmarathon01/digital-ember-vIms-/actions/workflows/ci.yml)

</div>