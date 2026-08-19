# SMS Fraud Detection System

A system for detecting fraudulent SMS activity, built using Agile methodology in sprint-based modules.

## Features
- User authentication (signup, login, forgot password)
- SMS fraud detection engine *(upcoming sprints)*
- Audit logging for security & fraud analysis

## Tech Stack
- Backend: _[e.g. Springboot / PostgreSQL]_
- Frontend: _[e.g. Flutter]_

## Getting Started

```bash
git clone <repo-url>
cd sms-fraud-detection
```

1. Install dependencies (backend & frontend)
2. Copy `.env.example` to `.env` and fill in your config
3. Run DB migrations
4. Start the dev server

## Modules
- `auth/` — Signup, login, session, password reset (Sprint 1) → see `auth/README.md`
- `fraud-engine/` — SMS fraud detection logic (upcoming)

## Contributing
- Follow the team's branching strategy (e.g. `feature/`, `bugfix/`)
- Open a PR against `develop` for review before merging

## Status
🚧 In development — Sprint 1 (Authentication Module)