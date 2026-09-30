# AGENTS.md

# Project: AI-Supported Healthy Living and Consulting Platform

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

### Mert

Primary responsibility:

- Flutter mobile application
- ASP.NET Core backend
- REST APIs
- Entity Framework Core
- PostgreSQL integration
- Authentication and authorization
- Database migrations
- AI / Computer Vision
- Python FastAPI AI service
- Camera integrations
- GPS / running tracking
- Health Connect / HealthKit integrations

### Uğur

Primary responsibility:

- React web application
- TypeScript
- Trainer dashboard
- Dietitian dashboard
- Admin screens
- Client management screens
- Workout assignment interfaces
- Nutrition assignment interfaces
- Web charts and dashboards
- Web API integrations

### Shared Responsibilities

- System architecture
- Database design decisions
- Testing
- Documentation
- UI/UX decisions
- Graduation report
- Presentation
- Integration testing

Do not modify another developer's primary area unnecessarily.

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

Database migrations are primarily managed from the backend project.

Do not:

- rename existing tables without approval
- rename existing columns without approval
- delete database fields without checking usage
- create duplicate entities
- create unnecessary tables

Before changing the database schema, check:

`docs/DATA_DICTIONARY.md`

---

## 6. API Rules

ASP.NET Core is the main application API.

Mobile and Web applications communicate with the system using REST APIs.

API definitions must follow:

`docs/API_CONTRACT.md`

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

Examples:

feature/auth-api

feature/workout-api

feature/mobile-workout

feature/web-trainer-dashboard

feature/ai-food

feature/ai-equipment

feature/running-tracking

After completing a task:

feature branch
↓
Pull Request
↓
Review
↓
main

Keep commits focused.

Do not include unrelated changes in the same commit.

---

## 15. Codex Rules

When working on a task:

1. Read this file.
2. Read relevant files under `/docs`.
3. Inspect the existing implementation.
4. Reuse existing structures.
5. Avoid unnecessary refactoring.
6. Modify only files required for the task.
7. Preserve existing naming conventions.
8. Do not create duplicate models or services.
9. Do not silently change API contracts.
10. Do not silently modify the database schema.

If a task requires an architectural, database or API contract change, clearly state it before implementing.

---

## 16. Scope Control

This is a two-person university graduation project.

Avoid expanding the scope unnecessarily.

Priority order:

1. Authentication
2. Database
3. User / Advisor system
4. Workout system
5. Mobile application
6. Trainer / Dietitian web panel
7. Progress tracking
8. Nutrition
9. Running tracking
10. AI equipment recognition
11. AI food recognition
12. Health integrations
13. Testing
14. Deployment

A working end-to-end feature is more valuable than multiple unfinished features.

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
