# Changelog Format

Write changelog entries to `CHANGELOG.md` using this format:

```markdown
## {version} ({release_date})

### 🚀 Features

#### {short_desc}
{your user-friendly description here}

*[#{number}]({url}) by @{author}*

### 🐛 Bug Fixes
...

### ♻️ Refactoring
...
```

## Section Order

Only include sections that have PRs:

1. 🚀 Features
2. 🐛 Bug Fixes
3. ♻️ Refactoring
4. 📚 Documentation
5. 🧪 Tests
6. 🔧 CI/Build
7. 📦 Other Changes

## Writing Guidelines

For each PR, write a **user-friendly description** that:

- Focuses on **value and impact** for the people who use the wiki, not technical implementation
- Is understandable by someone who uses the plugin but isn't a developer
- Is 1-2 sentences maximum

### By Change Type

| Type | Focus on... | Example |
|------|-------------|---------|
| Features | What users can now DO | "You can now archive an entire topic wiki and restore it later." |
| Fixes | What problem was SOLVED | "Fixed an issue where deep queries skipped sibling-wiki matches." |
| Refactors | Brief note, mention no user-visible changes | "Internal restructuring of the reference docs. No user-visible changes." |

## Important

After the new version section, preserve all existing changelog content (previous versions).
