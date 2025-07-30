# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Setup and Dependencies
```bash
# Install dependencies
mix deps.get
mix setup  # Runs deps.get + ecto.setup

# Setup database
mix ecto.setup  # Creates DB, runs migrations, seeds
mix ecto.reset  # Drops DB and runs ecto.setup

# Install frontend dependencies
cd assets && npm install && cd ..
```

### Running the Application
```bash
# Start Phoenix server
mix phx.server

# Or inside IEx
iex -S mix phx.server
```

### Testing
```bash
# Run tests
mix test

# Run specific test file
mix test test/path/to/test_file.exs

# Run test with specific line number
mix test test/path/to/test_file.exs:42
```

### Code Quality
```bash
# Format code
mix format

# Run Credo for code analysis
mix credo
```

### Building Assets
```bash
# For production deployment
mix assets.deploy
```

## High-Level Architecture

Claper is an interactive presentation platform built with Phoenix Framework and Elixir. It enables real-time audience interaction during presentations through polls, forms, messages, and quizzes.

### Core Components

1. **Phoenix LiveView Architecture**
   - Real-time updates without JavaScript through WebSocket connections
   - LiveView modules in `lib/claper_web/live/` handle interactive UI
   - Presence tracking for real-time user counts

2. **Main Domain Contexts** (in `lib/claper/`)
   - `Accounts` - User management, authentication, OIDC integration
   - `Events` - Core presentation/event management
   - `Posts` - Audience messages and reactions
   - `Polls` - Interactive polls with real-time voting
   - `Forms` - Custom forms for audience feedback
   - `Quizzes` - Quiz functionality with LTI support
   - `Presentations` - Slide management and state tracking
   - `Embeds` - External content embedding

3. **Authentication & Authorization**
   - Multiple auth methods: email/password, OIDC
   - Role-based access control with admin panel
   - LTI 1.3 support for educational platforms

4. **Real-time Features**
   - Phoenix PubSub for broadcasting updates
   - Phoenix Presence for tracking online users
   - LiveView for reactive UI without custom JavaScript

5. **Background Jobs**
   - Oban for background job processing
   - Email sending

6. **Frontend Stack**
   - Tailwind CSS for styling (with DaisyUI components)
   - Alpine.js for minimal JavaScript interactions
   - esbuild for JavaScript bundling
   - Separate admin and user interfaces

7. **Key LiveView Modules**
   - `EventLive.Show` - Attendee view
   - `EventLive.Presenter` - Presenter control view
   - `EventLive.Manage` - Event management interface
   - `AdminLive.*` - Admin panel components

8. **Database Structure**
   - PostgreSQL with Ecto
   - Key models: User, Event, Post, Poll, Quiz, PresentationState
   - Soft deletes for users
   - UUID-based public identifiers

9. **LTI Integration**
   - LTI 1.3 support for quizzes, publish score to LMS
   - LTI launch handling in `LtiController`
