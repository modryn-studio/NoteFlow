# GitHub Issues Workflow (Two-Agent System)

## Overview

**Agent 1 (Claude Desktop):** Creates specs via GitHub MCP after reading codebase from project knowledge base  
**Agent 2 (VS Code Copilot):** Implements specs, uses CLI for GitHub interactions  

**Standard Flow:**
1. Agent 1 → Creates issue with detailed spec (via MCP)
2. Agent 2 → Reads spec, asks clarifying questions if needed until 95% confident
3. Agent 2 → Implements, commits, pushes to GitHub
4. Agent 2 → Comments "ready for review"
5. Agent 1 → Reviews commits via MCP, provides feedback
6. Iterate or close

---

## The Workflow

### 1. Agent 1 Creates Issue

**How Agent 1 works:**
- Reads codebase through **GitHub repo synced in project knowledge base**
- Uses **GitHub MCP** to create issue directly with full spec
- No template needed - creates structured spec in issue body
- **REQUIRED:** Issue title MUST start with "Agent 1: " prefix

**Typical Agent 1 prompt:**
```
"Create a GitHub issue in {OWNER}/{REPO} with title 'Agent 1: [FEATURE/BUG]'.
Include problem statement, proposed solution, implementation plan."
```

### 2. Agent 2 Reviews Spec

**Agent 2's job:**
- Read the issue via GitHub extension
- **If straightforward:** Proceed to implementation
- **If complex:** Ask clarifying questions until 95% confident

**When to ask questions (Agent 2):**
- ✅ Unclear requirements or edge cases
- ✅ Multiple valid approaches (which one?)
- ✅ Security/performance concerns
- ✅ Missing technical details
- ❌ Don't ask if spec is clear and actionable

**HOW to ask questions:**
```bash
# Post questions as GitHub issue comment (Agent 1 sees via MCP)
# REQUIRED: Start with "Agent 2: " prefix
gh issue comment X --body "Agent 2: Question about Issue #Y: [your question]"

# For multiple questions, use --body-file
echo "Agent 2: ## Clarifying Questions..." > temp.md
gh issue comment X --body-file temp.md
rm temp.md
```

**Don't ask the user in chat** - Agent 1 created the spec and monitors issue comments via MCP.

### 3. Agent 2 Implements

```bash
# Pull latest
git pull origin main

# Implement the feature/fix

# Stage changes
git add .

# Commit with issue reference
git commit -m "Fix [issue] from #X

- Bullet summary of changes
- What was modified
- Build/test status"

# 🚨 CRITICAL: Build/test BEFORE pushing to verify no errors
npm run build  # or: npm test, cargo build, mvn verify, etc.

# Push to GitHub (Agent 1 reviews via MCP)
git push origin main  # or your default branch
```

**⚠️ Why push first:**
- Agent 1 reviews via GitHub MCP (cannot see local changes)
- No review possible until code is on GitHub

### 4. Agent 2 Comments "Ready for Review"

```bash
# For SHORT comments
# REQUIRED: Start with "Agent 2: " prefix
gh issue comment X --body "Agent 2: Implementation complete, ready for review"

# For LONG comments (use file to avoid PowerShell issues)
echo "Agent 2: Your detailed summary..." > temp.md
gh issue comment X --body-file temp.md
rm temp.md
```

**PowerShell tip:** Always use `--body-file` for multi-line comments (markdown, tables, code blocks)

### 5. Agent 1 Reviews Code

**Agent 1's review process:**
- Reads commits from GitHub via MCP (no local pull needed)
- Checks implementation matches spec
- Verifies edge cases, security, performance
- Comments on issue with feedback

### 6. Close or Iterate

- ✅ **Approved:** Agent 1 closes issue
- 🔄 **Changes needed:** Agent 2 makes updates, pushes, repeats step 4


---

## Common Commands

### Agent 2 CLI Reference

```bash
# View open issues
gh issue list --label "agent-spec"

# View specific issue
gh issue view X

# Short comment (ALWAYS start with "Agent 2: ")
gh issue comment X --body "Agent 2: Implementation complete"

# Long comment (ALWAYS use file for multi-line)
echo "Agent 2: ## Summary..." > temp.md
gh issue comment X --body-file temp.md
rm temp.md

# Check git status
git status

# View recent commits
git log --oneline -5
```

### Why Use `--body-file` for Long Comments?

PowerShell breaks with:
- Multiple paragraphs
- Markdown tables
- Code blocks
- Special characters

**Pattern:** Create temp file → Post with `--body-file` → Delete

---

## Agent Capabilities

| Capability | Agent 1 (Claude Desktop) | Agent 2 (VS Code Copilot) |
|-----------|------------------------|--------------------------|
| **Read codebase** | Via project knowledge base | Via workspace files |
| **Create issues** | ✅ Via MCP | ✅ Via CLI (`gh issue create`) |
| **Read issues** | ✅ Via MCP | ✅ Via GitHub extension |
| **Comment on issues** | ✅ Via MCP | ✅ Via CLI (`gh issue comment`) |
| **Review commits** | ✅ Via MCP (diffs, history) | ✅ Via git commands |
| **Implement code** | ❌ No local access | ✅ Full VS Code access |

---

## Best Practices

### For Agent 1 (Issue Creation)
- ✅ **Start issue title with "Agent 1: " prefix**
- ✅ Read repo via project knowledge before creating issue
- ✅ Include clear problem statement and solution
- ✅ Specify files/components affected
- ✅ Note edge cases or security concerns
- ✅ Provide implementation hints if helpful

### For Agent 2 (Implementation)
- ✅ **Start all issue comments with "Agent 2: " prefix**
- ✅ Ask clarifying questions if spec is unclear (95% confidence rule)
- ✅ Build/test project to verify no errors before pushing
- ✅ Commit with descriptive message + issue reference
- ✅ **Always build/test before pushing**
- ✅ **Always push before requesting review**
- ✅ Use `--body-file` for detailed comments
- ✅ Include build/test status in review request

### For Both Agents
- ✅ Act autonomously (no permission needed for standard workflow)
- ✅ Read what you need from repo/docs
- ✅ Comment directly on issues
- ✅ Reference commit hashes in reviews
- ❌ Don't ask user for permission to read files or post comments

---

## When to Use This Workflow

**Use for:**
- ✅ Complex features requiring spec-first approach
- ✅ Architectural changes needing documentation
- ✅ Bug fixes requiring analysis before implementation
- ✅ Features where Agent 2 needs clear requirements

**Don't use for:**
- ❌ Trivial typo fixes
- ❌ Simple content updates
- ❌ Emergency hotfixes (just do it)
