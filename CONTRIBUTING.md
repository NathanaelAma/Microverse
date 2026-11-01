# Contributing Guide

Thank you for your interest in Microverse! We welcome all kinds of contributions, including but not limited to code, documentation, testing, feedback, and suggestions.

## 🤝 How to Contribute

### Reporting Issues

If you find a bug or have a feature suggestion, please:

1. First check the [existing Issues](https://github.com/KsanaDock/Microverse/issues) to make sure it hasn't already been reported
2. Create a new Issue with the following information:
   - A clear description of the problem
   - Steps to reproduce (for bugs)
   - Expected and actual behavior
   - System environment (operating system, Godot version, etc.)
   - Relevant screenshots or logs (if applicable)

### Submitting Code

#### Setup

1. Fork this project to your GitHub account
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/Microverse.git
   cd Microverse
   ```
3. Add the upstream repository:
   ```bash
   git remote add upstream https://github.com/KsanaDock/Microverse.git
   ```

#### Development Workflow

1. Create a new feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Develop:
   - Follow the project's code style
   - Add comments where needed
   - Make sure the code runs correctly

3. Commit your changes:
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

4. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

5. Open a Pull Request

## 📝 Code Style

### GDScript Conventions

1. **Naming**:
   - Use snake_case for variables and functions: `my_variable`, `calculate_damage()`
   - Use UPPER_CASE for constants: `MAX_HEALTH`, `DEFAULT_SPEED`
   - Use PascalCase for class names: `CharacterManager`, `DialogService`

2. **Indentation and formatting**:
   - Indent with tabs (the Godot default)
   - Keep lines to a maximum of 100 characters
   - Leave one blank line between functions

3. **Comments**:
   - Add comments for complex logic
   - Public functions should have doc comments
   - Write comments in English

4. **Example**:
   ```gdscript
   # Calculate the distance between two characters
   # @param character1: the first character
   # @param character2: the second character
   # @return: the distance between the two characters
   func calculate_distance(character1: Node2D, character2: Node2D) -> float:
       var distance = character1.global_position.distance_to(character2.global_position)
       return distance
   ```

### File Organization

1. **Script files**:
   - Organized by feature module under `script/`
   - AI-related scripts go in `script/ai/`
   - UI-related scripts go in `script/ui/`

2. **Scene files**:
   - Character scenes go in `scene/characters/`
   - UI scenes go in `scene/ui/`
   - Map scenes go in `scene/maps/`

3. **Asset files**:
   - Image assets go in the matching subdirectory of `asset/`
   - Font files go in `asset/fonts/`

## 🧪 Testing

The project doesn't have an automated test framework yet, but please make sure that:

1. Your code produces no errors in the Godot editor
2. The related features work correctly
3. Existing features are not broken

## 📚 Documentation

If your contribution adds a feature or changes an API:

1. Update the relevant documentation files
2. Add appropriate comments in the code
3. Update README.md if needed

## 🔄 Pull Request Process

1. **PR title**: Use a clear title that describes your change
   - `feat: add a new AI character system`
   - `fix: fix a memory leak in the dialog system`
   - `docs: update API documentation`

2. **PR description**:
   - Describe what you changed
   - Explain why you made the change
   - List related Issues (if any)
   - Provide testing instructions

3. **Code review**:
   - Maintainers will review your code
   - Make any necessary changes based on feedback
   - Once all checks pass, the PR will be merged

## 🎯 Contribution Areas

We especially welcome contributions in the following areas:

### Core Features
- AI dialog system optimization
- Integration of new AI service providers
- Character behavior and decision-making systems
- Memory system improvements

### User Interface
- UI/UX improvements
- New themes and styles
- Accessibility enhancements
- Mobile support

### Content Creation
- New characters and backstories
- Scene and map design
- Sound effects and music
- Localization and translation

### Technical Improvements
- Performance optimization
- Code refactoring
- Better error handling
- Logging and debugging tools

### Documentation and Tutorials
- API documentation
- Usage tutorials
- Development guides
- Example projects

## 🏷️ Commit Message Convention

Use the following prefixes to identify the commit type:

- `feat:` new feature
- `fix:` bug fix
- `docs:` documentation update
- `style:` code formatting (no functional change)
- `refactor:` code refactoring
- `test:` test-related changes
- `chore:` build process or tooling changes

Examples:
```
feat: add Kimi AI model support
fix: fix collision detection when characters move
docs: update API configuration docs
```

## 📞 Contact

If you have any questions or need help:

- Open an Issue for discussion
- Email: ksanadock@example.com
- Join our community discussions

## 📄 License

By contributing code, you agree that your contributions will be released under the MIT License.

---

Thanks again for contributing! Every contribution makes Microverse better.
