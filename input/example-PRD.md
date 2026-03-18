# Product Requirements Document (PRD) Template

> Replace this content with your actual project requirements.
> auto-dev will read all .md, .yaml, .json, .txt files in this directory.

## Project Overview

**Name:** My Project
**Goal:** One sentence describing what this project does.
**Tech Stack:** Next.js + TypeScript + PostgreSQL (or specify your own)

## Core Features

### Feature 1: User Authentication
- Sign up with email and password
- Sign in / sign out
- Password reset flow
- Session management with JWT

### Feature 2: Dashboard
- Display key metrics in cards
- Line chart for time-series data
- Table with pagination and sorting
- Date range filter

### Feature 3: Settings Page
- Update profile (name, email, avatar)
- Change password
- Notification preferences toggle

## Data Model

### Users
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| email | string | Unique, required |
| name | string | Required |
| password_hash | string | bcrypt |
| created_at | timestamp | Auto |
| updated_at | timestamp | Auto |

### Metrics
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| user_id | UUID | Foreign key → Users |
| name | string | Metric name |
| value | decimal | Use decimal, never float |
| recorded_at | timestamp | When recorded |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/auth/signup | Create account |
| POST | /api/auth/signin | Login |
| POST | /api/auth/signout | Logout |
| GET | /api/metrics | List metrics (paginated) |
| POST | /api/metrics | Create metric |
| GET | /api/user/profile | Get current user profile |
| PUT | /api/user/profile | Update profile |

## Pages / Routes

| Route | Description | Auth Required |
|-------|-------------|:---:|
| / | Landing page | No |
| /auth/signin | Login form | No |
| /auth/signup | Registration form | No |
| /dashboard | Main dashboard | Yes |
| /settings | User settings | Yes |

## Non-Functional Requirements

- All financial/numeric values must use decimal-safe arithmetic
- Minimum 80% test coverage
- Responsive design (mobile + desktop)
- Loading states for all async operations
- Error boundaries for graceful failure handling

## Out of Scope

- OAuth / social login (future phase)
- Multi-language support
- Real-time updates (WebSocket)
