# QuantFi Dashboard — Product Requirements Document

## Project Overview

**Name:** quantfi-dashboard
**Goal:** A quantitative finance data dashboard that displays stock market data, portfolio positions, and key financial metrics with interactive charts.
**Tech Stack:** Next.js 16 + TypeScript + PostgreSQL + Tailwind CSS v4

## Core Features

### Feature 1: Market Overview Page
- Display a grid of stock cards showing symbol, current price, daily change (%), and sparkline chart
- Support at least 10 preset stock symbols (AAPL, GOOGL, MSFT, AMZN, TSLA, META, NVDA, JPM, V, BRK.B)
- Color-coded price changes: green for positive, red for negative
- Auto-refresh every 60 seconds (simulated with mock data for now)

### Feature 2: Portfolio Tracker
- Table showing user's stock positions: symbol, quantity, average cost, current price, P&L, P&L%
- Summary row with total portfolio value, total cost basis, total P&L
- All monetary calculations must use decimal-safe arithmetic (decimal.js)
- Sort by any column
- Add/remove positions via a simple form

### Feature 3: Interactive Price Chart
- Line chart showing historical price data for a selected stock
- Time range selector: 1D, 1W, 1M, 3M, 1Y
- Hover tooltip showing date, open, high, low, close, volume
- Use Recharts library for charting

### Feature 4: Dashboard Layout
- Responsive sidebar navigation with icons
- Header with app title and dark/light mode toggle
- Main content area with grid layout
- Footer with last update timestamp
- Mobile-friendly: sidebar collapses to hamburger menu on small screens

## Data Model

### stocks
| Field | Type | Notes |
|-------|------|-------|
| id | serial | Primary key |
| symbol | varchar(10) | Unique, uppercase |
| name | varchar(100) | Company name |
| sector | varchar(50) | Industry sector |

### price_history
| Field | Type | Notes |
|-------|------|-------|
| id | serial | Primary key |
| stock_id | integer | Foreign key → stocks |
| date | date | Trading date |
| open | decimal(12,4) | Opening price |
| high | decimal(12,4) | Daily high |
| low | decimal(12,4) | Daily low |
| close | decimal(12,4) | Closing price |
| volume | bigint | Trading volume |

### positions
| Field | Type | Notes |
|-------|------|-------|
| id | serial | Primary key |
| stock_id | integer | Foreign key → stocks |
| quantity | decimal(12,4) | Number of shares |
| avg_cost | decimal(12,4) | Average cost per share |
| created_at | timestamp | When position was added |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /api/stocks | List all tracked stocks with latest price |
| GET | /api/stocks/[symbol]/history | Get price history for a stock (query: range=1D/1W/1M/3M/1Y) |
| GET | /api/portfolio | Get all positions with calculated P&L |
| POST | /api/portfolio | Add a new position (body: symbol, quantity, avg_cost) |
| DELETE | /api/portfolio/[id] | Remove a position |

## Pages / Routes

| Route | Description |
|-------|-------------|
| / | Dashboard home — market overview grid |
| /portfolio | Portfolio positions table |
| /stocks/[symbol] | Individual stock detail with price chart |

## Non-Functional Requirements

- All financial values use decimal.js (never floating-point)
- Responsive design: works on mobile (375px) through desktop (1920px)
- Loading skeletons for all async data
- Error boundaries with user-friendly fallback UI
- Dark mode support via Tailwind
- Mock data seeder for development (no external API dependency)

## Out of Scope (Future Phases)

- Real-time market data API integration (Alpha Vantage / Yahoo Finance)
- User authentication and multi-user support
- Trade execution
- Alerts and notifications
