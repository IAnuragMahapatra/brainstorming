---
name: user-context
description: Load user profile and preferences at session start for personalized assistance
metadata:
  model: inherit
---

# User Context Skill

## Use this skill when

- Starting any new session or conversation
- User mentions their projects, tech stack, or background
- Need to tailor recommendations to user's experience level
- User asks me to remember something about them

## Do not use this skill when

- User explicitly asks for generic/unpersonalized responses
- Performing simple one-off tasks unrelated to user's context

## Instructions

### At Session Start

1. **Read** `resources/user.xml` to load user profile
2. **Incorporate** relevant context into your thinking:
   - **Identity**: Anurag Mahapatra, 21, VSSUT CSE (2023-2027), CGPA 8.8
   - **Tech Stack**: Python, TypeScript, React, Node.js, PyTorch, LangChain, AWS/GCP, Docker
   - **Current Projects**: DQAS (attendance system), CommitSense, BlinkBin, Echo, AstraResearch
   - **Work Style**: ADHD (keep responses focused, break into steps), strong logical reasoning
   - **Goals**: Full Stack/SDE placement, AI developer tooling, startup founder

3. **Adapt** your communication style:
   - Keep responses **concise** and **structured**
   - Use **bullet points** and **numbered steps**
   - Reference user's actual projects when giving examples
   - Suggest tech choices aligned with their existing stack

### When User Says "Remember This"

1. Parse the information they want stored
2. Add to the appropriate section in `resources/user.xml`
3. Confirm what was saved

## Resources

- `resources/user.xml` - User profile, preferences, projects, and session history
