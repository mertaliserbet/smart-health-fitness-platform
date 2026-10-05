# AGENTS.md

# Project: Yapay Zekâ Destekli Sağlık ve Fitness Platformu

This repository contains a university graduation project developed by two developers.

The system consists of:

- Flutter mobile application
- React + TypeScript web application
- ASP.NET Core Web API
- PostgreSQL database
- Python / FastAPI AI service

The project must remain maintainable, consistent and realistic for a two-person team.

---

## 1. Project Structure

Expected repository structure:

/backend
/mobile
/web
/ai
/docs

Backend:
ASP.NET Core Web API

Mobile:
Flutter + Dart

Web:
React + TypeScript

AI:
Python + FastAPI

Database:
PostgreSQL

---

## 2. Developer Responsibilities

The project is intentionally divided so both developers can work in parallel with separate Codex sessions.

Each developer owns a client application and a set of backend domains.

The goal is to avoid placing the entire backend, database and integration workload on one developer.

### Mert — Mobile, Tracking and AI Track

Primary responsibility:

#### Mobile

- Flutter mobile application
- Mobile navigation and screen structure
- Mobile state management
- Mobile API client integration
- User profile and settings screens
- Home / My Plan / AI / Tracking / My Advisors mobile flows
- Camera and gallery integrations
- GPS / running tracking
- Health Connect / HealthKit integrations

#### Backend domains owned by Mert

- Authentication and authorization foundation
- JWT Access Token and Refresh Token flow
- User account and profile APIs
- Weight and body measurement APIs
- Running activity APIs
- Health / wearable data integration APIs
- AI request orchestration endpoints
- Media/image upload endpoints required by AI features
- Shared backend error handling and authentication middleware

#### AI

- Python / FastAPI AI service
- Food image recognition
- Gym equipment recognition
- Computer vision pipeline
- AI model inference endpoints
- AI result validation/integration with ASP.NET Core backend

### Uğur — Web, Advisor, Workout and Nutrition Track

Primary responsibility:

#### Web

- React + TypeScript web application
- Web routing and application structure
- Web state management
- Web API client integration
- Trainer dashboard
- Dietitian dashboard
- Admin screens
- Client management screens
- Workout assignment interfaces
- Nutrition assignment interfaces
- Web charts and dashboards

#### Backend domains owned by Uğur

- Trainer APIs
- Dietitian APIs
- Advisor / UserAdvisor APIs
- Client management APIs
- Exercise APIs
- WorkoutPlan / WorkoutDay / WorkoutExercise APIs
- Workout assignment APIs
- WorkoutSession / WorkoutLog APIs required by advisor workflows
- Nutrition target and nutrition assignment APIs
- Advisor notes and task APIs
- Simple V1 admin management APIs

### Shared Responsibilities

- System architecture decisions
- Cross-domain database design decisions
- API contract review
- Integration testing
- End-to-end testing
- Documentation
- UI/UX consistency
- Graduation report
- Presentation
- Deployment preparation

### Ownership Rule

A developer may create and modify backend code inside the domains assigned to that developer.

Do not treat `/backend` as belonging to only one person. Backend ownership is domain-based.

Mert should not implement Uğur-owned workout/advisor/nutrition modules unless both developers explicitly agree.

Uğur should not implement Mert-owned authentication/tracking/AI integration modules unless both developers explicitly agree.

Do not modify another developer's client application (`/mobile` or `/web`) unnecessarily.

When one track needs functionality from the other track, agree on the API contract first and integrate through the contract instead of duplicating the feature.

---

## 3. Required Documentation

Before creating or modifying important project structures, read:

- docs/PROJECT_CONTEXT.md
- docs/NAMING_CONVENTIONS.md
- docs/DATA_DICTIONARY.md
- docs/API_CONTRACT.md

These files are the source of truth for project terminology and API structures.

Do not invent alternative names for existing concepts.

Example:

If the project uses:

`WorkoutPlan`

do not create alternative concepts such as:

`TrainingPlan`
`ExercisePlan`
`WorkoutProgram`

unless the project documentation is updated first.

---

## 4. Naming Rules

Follow:

`docs/NAMING_CONVENTIONS.md`

Existing naming conventions must not be changed without a clear reason.

Avoid creating duplicate concepts with different names.

Before introducing a new:

- Entity
- DTO
- Database table
- Database column
- API endpoint
- Model
- Service

check whether an equivalent structure already exists.

---

## 5. Database Rules

PostgreSQL is the main database.

Entity Framework Core is used by the backend.

Mobile, Web and AI services must NEVER connect directly to PostgreSQL.

Correct architecture:

Mobile
   ↓
ASP.NET Core API
   ↓
PostgreSQL

Web
   ↓
ASP.NET Core API
   ↓
PostgreSQL

AI services communicate through the backend when application data is involved.

### Database ownership

Database work is shared by domain ownership instead of being assigned to a single developer.

- Mert manages entities/configurations required by Auth, User/Profile, Tracking, Running, Health and AI integration domains.
- Uğur manages entities/configurations required by Advisor, Exercise, Workout, Nutrition, Client Management and Admin domains.
- Cross-domain relationships must be reviewed by both developers before implementation.
- The developer introducing a schema change is responsible for updating the related entity configuration and documentation.
- Database migrations may be created by either developer for that developer's owned domain.

Before creating a migration, sync with the latest `main` branch to reduce migration conflicts.

If both developers need schema changes at the same time, keep them in separate feature branches and merge them one at a time. The second branch must rebase/sync and regenerate or verify its migration if required.

Do not:

- rename existing tables without approval
- rename existing columns without approval
- delete database fields without checking usage
- create duplicate entities
- create unnecessary tables

Before changing the database schema, check:

`docs/DATA_DICTIONARY.md`

When the schema changes, update `docs/DATA_DICTIONARY.md` in the same feature or PR.

---

## 6. API Rules

ASP.NET Core is the main application API.

Mobile and Web applications communicate with the system using REST APIs.

API definitions must follow:

`docs/API_CONTRACT.md`

Backend API ownership follows the domain ownership defined in Section 2.

- Mert owns API implementation for Auth, User/Profile, Tracking, Running, Health and AI integration domains.
- Uğur owns API implementation for Advisor, Exercise, Workout, Nutrition, Client Management and Admin domains.

The owner of a new endpoint is also responsible for its controller/endpoint, service, DTOs, validation, authorization, tests and API contract documentation.

Do not change an existing:

- endpoint
- request model
- response model
- route
- field name

without checking its usage in Mobile and Web.

When introducing a new endpoint:

1. Check whether an existing endpoint can be reused.
2. Follow existing route conventions.
3. Use appropriate HTTP methods.
4. Define request and response DTOs.
5. Update `docs/API_CONTRACT.md`.
6. Inform the other track if that endpoint is consumed by both Mobile and Web.

### Contract-first parallel development

If Mobile or Web needs an endpoint that is not implemented yet:

1. Define the request/response contract in `docs/API_CONTRACT.md`.
2. Agree on route, DTO fields and expected authorization.
3. The client-side developer may continue with mock/stub data based on that contract.
4. The backend domain owner implements the real endpoint.
5. Replace the mock with real API integration after the endpoint is merged.

Do not create a duplicate temporary endpoint just to unblock another client.

---

## 7. Authentication and Authorization

Authentication will use:

- JWT Access Token
- Refresh Token

Authorization will use role and/or claim based authorization.

Main roles include:

- User
- Trainer
- Dietitian
- Admin

Do not implement authorization only on the frontend.

Backend authorization is mandatory for protected operations.

---

## 8. Main Domain Concepts

Important concepts include:

- User
- Trainer
- Dietitian
- Advisor
- UserAdvisor
- Exercise
- WorkoutPlan
- WorkoutDay
- WorkoutExercise
- WorkoutSession
- WorkoutLog
- WeightRecord
- BodyMeasurement
- NutritionRecord
- FoodRecognition
- GymEquipment
- EquipmentExercise
- AIRecognitionLog
- RunningActivity

Use the terminology defined in:

`docs/DATA_DICTIONARY.md`

---

## 9. Mobile Application

The mobile application is primarily for normal users.

Main navigation:

- Home
- My Plan
- AI
- Tracking
- My Advisors

Profile and settings should be accessed separately from the main navigation.

### Home

Shows summary information such as:

- today's workout
- calorie status
- activity summary
- weight progress
- trainer/dietitian assignments

### My Plan

Contains:

- workout plans
- nutrition targets
- trainer assignments
- dietitian assignments
- tasks and recommendations

### AI

Contains:

- food image recognition
- estimated calories/macros
- gym equipment recognition
- exercises related to recognized equipment

### Tracking

Contains:

- weight
- body measurements
- nutrition history
- calorie history
- running activities
- steps
- wearable data
- progress charts

### My Advisors

Contains:

- Trainer information
- Dietitian information
- assigned plans
- advisor notes

---

## 10. Web Application

The web application is primarily used by:

- Trainer
- Dietitian
- Admin

Trainer features include:

- dashboard
- client list
- client detail
- workout plan creation
- workout assignment
- progress monitoring
- notes/tasks

Dietitian features include:

- dashboard
- client list
- client detail
- nutrition targets
- calorie/macro targets
- nutrition assignments
- progress monitoring
- notes/tasks

Admin features should remain simple for V1.

---

## 11. AI Services

The AI service uses Python and FastAPI.

Main AI features:

### Gym Equipment Recognition

Input:

Image

Output:

Recognized equipment

Example:

Lat Pulldown

Exercise recommendations must NOT be stored inside the AI model.

The backend/database is responsible for mapping equipment to exercises.

### Food Recognition

Input:

Food image

Output may contain:

- detected food
- estimated portion
- estimated calories
- estimated protein
- estimated carbohydrates
- estimated fat

AI-generated nutrition values are estimates.

The user should be able to correct the result before saving it.

---

## 12. Running and Health Data

Running tracking may use:

- GPS
- distance
- duration
- pace
- speed
- route
- estimated calories

Wearable and health data should preferably use:

Android:
Health Connect

iOS:
Apple Health / HealthKit

Avoid direct integrations with every smartwatch manufacturer unless required.

---

## 13. Architecture Principles

Prefer simple and maintainable architecture.

Do NOT introduce unnecessary complexity.

Backend should follow a modular structure.

Microservices are NOT required.

The Python AI service may remain separate.

Avoid:

- unnecessary abstraction
- unnecessary design patterns
- premature optimization
- duplicated services
- duplicated DTOs
- unnecessary dependencies

Implement the simplest maintainable solution.

---

## 14. Git Rules

Do not work directly on `main` for feature development.

Use feature branches.

Recommended branch naming:

### Mert examples

- `feature/mert-auth-api`
- `feature/mert-mobile-profile`
- `feature/mert-running-tracking`
- `feature/mert-ai-food`
- `feature/mert-ai-equipment`

### Uğur examples

- `feature/ugur-advisor-api`
- `feature/ugur-workout-api`
- `feature/ugur-nutrition-api`
- `feature/ugur-web-trainer-dashboard`
- `feature/ugur-web-dietitian-dashboard`

After completing a task:

feature branch
↓
Pull Request
↓
Review
↓
main

Before starting a new feature branch, sync with the latest `main`.

Keep commits focused.

Do not include unrelated changes in the same commit.

Avoid having both developers edit the same shared file at the same time when possible.

High-conflict shared files include:

- `docs/API_CONTRACT.md`
- `docs/DATA_DICTIONARY.md`
- backend DbContext files
- migration files
- authentication configuration
- solution/project configuration files

When a shared file must change, keep the change small and merge it early.

---

## 15. Codex Rules

Each developer may use a separate Codex session/worktree for independent development.

Codex must respect the ownership boundaries in Section 2.

### General task rules

When working on a task:

1. Read this file.
2. Read relevant files under `/docs`.
3. Inspect the existing implementation.
4. Confirm which developer/domain owns the task.
5. Reuse existing structures.
6. Avoid unnecessary refactoring.
7. Modify only files required for the task.
8. Preserve existing naming conventions.
9. Do not create duplicate models or services.
10. Do not silently change API contracts.
11. Do not silently modify the database schema.
12. Do not refactor the other developer's area as a side effect of the task.

If a task requires an architectural, database or API contract change, clearly state it before implementing.

### Mert Codex working area

Mert's Codex should normally limit changes to:

- `/mobile`
- `/ai`
- Mert-owned backend domains
- tests related to Mert-owned domains
- documentation directly related to those changes

Mert's Codex may consume Uğur-owned APIs but should not implement or redesign those domains without agreement.

### Uğur Codex working area

Uğur's Codex should normally limit changes to:

- `/web`
- Uğur-owned backend domains
- tests related to Uğur-owned domains
- documentation directly related to those changes

Uğur's Codex may consume Mert-owned APIs but should not implement or redesign those domains without agreement.

### Parallel-development rule

Both Codex sessions may work at the same time when their tasks do not edit the same implementation area.

Good parallel examples:

- Mert: authentication API + mobile login
- Uğur: trainer dashboard shell + advisor/client backend

- Mert: running tracking API + Flutter tracking screen
- Uğur: workout plan API + trainer workout editor

- Mert: food recognition AI service + mobile camera flow
- Uğur: nutrition target API + dietitian nutrition screen

If one task depends on another developer's unfinished endpoint, use the documented API contract and mock data rather than implementing the other developer's domain.

### Integration checkpoints

After a feature is merged:

1. Pull latest `main`.
2. Run relevant backend tests.
3. Run the affected client application.
4. Verify request/response compatibility.
5. Remove temporary mocks once the real endpoint is available.
6. Fix integration issues before starting another large dependent feature.

---

## 16. Scope Control

This is a two-person university graduation project.

Avoid expanding the scope unnecessarily.

A working end-to-end feature is more valuable than multiple unfinished features.

### Parallel implementation roadmap

The project should progress in parallel tracks instead of waiting for one developer to finish the entire backend first.

#### Phase 1 — Foundation

Mert:

- backend project foundation
- authentication / authorization
- user/profile API
- Flutter project foundation
- mobile login/register/profile flow

Uğur:

- React project foundation
- web login/session handling
- Advisor / UserAdvisor model and API preparation
- trainer/dietitian dashboard shell

Shared:

- initial database conventions
- API contract conventions
- shared domain terminology

#### Phase 2 — Core fitness workflow

Mert:

- mobile Home / My Plan foundations
- weight and body measurement tracking
- mobile progress screens

Uğur:

- Exercise domain
- WorkoutPlan / WorkoutDay / WorkoutExercise APIs
- trainer client list/detail
- trainer workout plan creation and assignment

Shared integration:

- assigned workout plans displayed in Mobile
- workout progress visible in Web

#### Phase 3 — Nutrition and advisor workflow

Mert:

- mobile nutrition history and calorie summary
- advisor information on Mobile
- related mobile API integrations

Uğur:

- nutrition target/assignment APIs
- dietitian client screens
- calorie/macro target interfaces
- advisor notes/tasks

Shared integration:

- dietitian targets displayed in Mobile
- user nutrition progress displayed in Web

#### Phase 4 — Running and AI

Mert:

- GPS running tracking
- RunningActivity backend
- food recognition AI
- gym equipment recognition AI
- mobile camera/gallery AI flows

Uğur:

- workout/progress dashboard improvements
- nutrition/progress dashboard improvements
- admin V1 screens
- AI recognition history views on Web only if required by scope

Shared integration:

- AI results saved through ASP.NET Core backend
- recognized equipment mapped to exercises from backend/database

#### Phase 5 — Finalization

Mert:

- Health Connect / HealthKit if time permits
- mobile polish and error handling
- AI evaluation and demo preparation

Uğur:

- web polish and error handling
- admin V1 completion
- dashboard/report improvements

Shared:

- testing
- integration fixes
- security review
- documentation
- deployment
- graduation report
- presentation

### Scope priority

Must-have:

1. Authentication
2. User / Advisor relationship
3. Workout planning and assignment
4. Mobile workout display/tracking
5. Trainer / Dietitian web panel
6. Weight/body progress tracking
7. Nutrition targets and progress
8. At least one working AI recognition feature
9. End-to-end testing
10. Deployment/demo environment

Should-have if time allows:

- running tracking
- second AI recognition feature
- richer charts/reports
- simple admin tools

Optional / final-stage:

- Health Connect / HealthKit
- advanced wearable integrations
- non-essential analytics
- extra AI features

---

## 17. Definition of Done

A feature is complete only when:

- implementation is finished
- API integration works
- authorization is correct
- database operations work
- errors are handled
- basic tests are completed
- related documentation is updated when necessary
- the feature works end-to-end

Do not mark partially integrated features as complete.
