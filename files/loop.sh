#!/bin/bash
# Usage: ./loop.sh [plan] [max_iterations] [provider]
# Examples:
#   ./loop.sh                    # Build mode, unlimited iterations, Claude (default)
#   ./loop.sh 20                 # Build mode, max 20 iterations, Claude
#   ./loop.sh plan               # Plan mode, unlimited iterations, Claude
#   ./loop.sh plan 5             # Plan mode, max 5 iterations, Claude
#   ./loop.sh plan 0 openai      # Plan mode, unlimited iterations, OpenAI
#   ./loop.sh 10 openai          # Build mode, max 10 iterations, OpenAI

# Parse arguments
PROVIDER="claude"  # Default provider

if [ "$1" = "plan" ]; then
    # Plan mode
    MODE="plan"
    PROMPT_FILE="PROMPT_plan.md"
    MAX_ITERATIONS=${2:-0}
    [ -n "$3" ] && PROVIDER="$3"
elif [[ "$1" =~ ^[0-9]+$ ]]; then
    # Build mode with max iterations
    MODE="build"
    PROMPT_FILE="PROMPT_build.md"
    MAX_ITERATIONS=$1
    [ -n "$2" ] && PROVIDER="$2"
else
    # Build mode, unlimited (no arguments or invalid input)
    MODE="build"
    PROMPT_FILE="PROMPT_build.md"
    MAX_ITERATIONS=0
    [ -n "$1" ] && PROVIDER="$1"
fi

ITERATION=0
CURRENT_BRANCH=$(git branch --show-current)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mode:     $MODE"
echo "Provider: $PROVIDER"
echo "Prompt:   $PROMPT_FILE"
echo "Branch:   $CURRENT_BRANCH"
[ $MAX_ITERATIONS -gt 0 ] && echo "Max:      $MAX_ITERATIONS iterations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verify prompt file exists
if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: $PROMPT_FILE not found"
    exit 1
fi

while true; do
    if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
        echo "Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    # Run Ralph iteration with selected prompt
    # run: Non-interactive mode (reads prompt from file)
    # --format json: Structured output for logging/monitoring (raw JSON events)
    # --model: Plan mode uses Opus/GPT-5.2-Codex for complex reasoning (task selection, prioritization)
    #          Build mode uses Sonnet/GPT-5.2-Codex for speed when plan is clear and tasks well-defined
    # Note: OpenCode auto-approves tool calls in non-interactive mode by default
    
    # Select model based on provider and mode
    if [ "$PROVIDER" = "openai" ]; then
        if [ "$MODE" = "plan" ]; then
            MODEL="openai/gpt-5.2-codex"
        else
            MODEL="openai/gpt-5.2-codex"
        fi
    else
        # Default to Claude via OpenCode Zen
        if [ "$MODE" = "plan" ]; then
            MODEL="opencode/claude-opus-4-5"
        else
            MODEL="opencode/claude-sonnet-4-5"
        fi
    fi
    
    opencode run --format json --model "$MODEL" "$(cat "$PROMPT_FILE")"

    # Push changes after each iteration
    git push origin "$CURRENT_BRANCH" || {
        echo "Failed to push. Creating remote branch..."
        git push -u origin "$CURRENT_BRANCH"
    }

    ITERATION=$((ITERATION + 1))
    echo -e "\n\n======================== LOOP $ITERATION ========================\n"
done