---
name: creating-test-cases
description: Designs comprehensive test cases using systematic techniques (boundary value analysis, equivalence partitioning, mutation testing, property-based testing). Use when writing tests, improving test coverage, finding edge cases, or when user mentions test cases, testing, or test design.
---

# Creating Test Cases

Design comprehensive test cases that systematically find bugs using proven QA techniques.

**Use this skill when** writing new tests, improving test coverage, finding edge cases, designing test strategies, or reviewing test quality.

**Supporting files:** [TECHNIQUES.md](references/TECHNIQUES.md) for detailed techniques, [BUG-PATTERNS.md](references/BUG-PATTERNS.md) for common bug types, [GO-TESTING.md](references/GO-TESTING.md) for Go-specific patterns, [HEURISTICS.md](references/HEURISTICS.md) for testing mnemonics.

## Quick Start

Apply systematic techniques to find bugs others miss:

```go
func TestCalculateDiscount(t *testing.T) {
    tests := map[string]struct {
        price    float64
        quantity int
        want     float64
        wantErr  bool
    }{
        // Equivalence Partitions
        "valid small order":  {100, 5, 500, false},
        "valid bulk order":   {100, 100, 9000, false}, // 10% bulk discount

        // Boundary Values
        "quantity zero":      {100, 0, 0, false},
        "quantity one":       {100, 1, 100, false},
        "bulk threshold-1":   {100, 49, 4900, false},
        "bulk threshold":     {100, 50, 4500, false}, // discount kicks in
        "bulk threshold+1":   {100, 51, 4590, false},

        // Error Cases
        "negative quantity":  {100, -1, 0, true},
        "negative price":     {-100, 5, 0, true},
        "zero price":         {0, 5, 0, false},

        // Edge Cases (Error Guessing)
        "max int quantity":   {1, math.MaxInt32, 0, true},
        "float precision":    {0.1, 3, 0.3, false},
    }

    for name, tc := range tests {
        t.Run(name, func(t *testing.T) {
            // test implementation
        })
    }
}
```

## Test Design Workflow

Follow this systematic process:

```
Test Design Checklist:
- [ ] Step 1: Analyze requirements and identify test conditions
- [ ] Step 2: Apply specification-based techniques (EP, BVA, DT)
- [ ] Step 3: Apply structure-based techniques (coverage analysis)
- [ ] Step 4: Apply experience-based techniques (error guessing)
- [ ] Step 5: Prioritize using RCRCRC heuristic
- [ ] Step 6: Validate test quality (mutation testing)
```

## Step 1: Analyze Requirements

Identify inputs, outputs, preconditions, and invariants:

| Aspect | Questions to Answer |
|--------|---------------------|
| Inputs | What are valid/invalid ranges? What types? |
| Outputs | What should success look like? What errors? |
| Preconditions | What state must exist before the operation? |
| Invariants | What must remain true throughout? |
| Side Effects | What state changes occur? |

## Step 2: Specification-Based Techniques

### Equivalence Partitioning (EP)

Divide input domain into classes where behavior is equivalent:

```
Input: age (integer)
Partitions:
- Invalid: age < 0
- Minor: 0 <= age < 18
- Adult: 18 <= age < 65
- Senior: age >= 65

Test one value from each partition:
- age = -5 (invalid)
- age = 10 (minor)
- age = 30 (adult)
- age = 70 (senior)
```

### Boundary Value Analysis (BVA)

Test at partition boundaries where bugs cluster:

```
For partition boundaries at 0, 18, 65:
Test: -1, 0, 1, 17, 18, 19, 64, 65, 66
```

### Decision Table Testing

For complex business logic with multiple conditions:

| Conditions        | R1 | R2 | R3 | R4 |
|-------------------|----|----|----|----|
| Premium member    | Y  | Y  | N  | N  |
| Order > $100      | Y  | N  | Y  | N  |
| **Actions**       |    |    |    |    |
| Apply 20% off     | X  |    |    |    |
| Apply 10% off     |    | X  | X  |    |
| No discount       |    |    |    | X  |

### State Transition Testing

For stateful systems:

```
States: [Idle] -> [Processing] -> [Complete/Failed]

Test transitions:
1. Idle -> Processing (valid: submit order)
2. Processing -> Complete (valid: payment success)
3. Processing -> Failed (valid: payment declined)
4. Idle -> Complete (invalid: should fail)
```

## Step 3: Structure-Based Techniques

Target coverage metrics:

| Level | Coverage Target | When to Use |
|-------|-----------------|-------------|
| Statement | 80%+ | Minimum for production code |
| Branch | 80%+ | Conditional logic |
| MC/DC | 100% | Safety-critical systems |

**Branch coverage example:**
```go
func process(a, b bool) string {
    if a && b {      // Branch 1: both true
        return "both"
    } else if a {    // Branch 2: only a
        return "a"
    } else {         // Branch 3: neither/only b
        return "other"
    }
}

// Tests for 100% branch coverage:
// {true, true} -> "both"   (Branch 1)
// {true, false} -> "a"     (Branch 2)
// {false, true} -> "other" (Branch 3)
// {false, false} -> "other" (Branch 3, redundant)
```

## Step 4: Experience-Based Techniques

### Error Guessing

Target common bug patterns:

| Category | Examples to Test |
|----------|------------------|
| Off-by-one | Loop bounds, array indices, fencepost |
| Null/Empty | nil, "", [], {} |
| Numeric | 0, -1, MAX_INT, MIN_INT, NaN, Inf |
| Strings | Unicode, very long, special chars |
| Concurrency | Race conditions, deadlocks |
| Resources | Leaks, exhaustion, timeouts |

### RCRCRC Prioritization

Prioritize test areas:

| Letter | Focus | What to Test |
|--------|-------|--------------|
| **R**ecent | New/changed code | Features added in current sprint |
| **C**ore | Critical functionality | Main business flows, payment |
| **R**isk | High-risk areas | Complex algorithms, security |
| **C**onfiguration | Environment-dependent | DB connections, API keys |
| **R**epaired | Recently fixed bugs | Regression tests for fixes |
| **C**hronic | Frequently failing | Areas with bug history |

## Step 5: Validate Test Quality

### Mutation Testing

Verify tests can detect code changes:

```bash
# Go mutation testing
go-mutesting ./...

# Interpret results:
# - Killed mutants: Tests detected the change (good)
# - Survived mutants: Tests missed the change (add tests)
# - Mutation score: killed / total (aim for >80%)
```

### Property-Based Testing

Test invariants across many random inputs:

```go
func TestReverse_Involution(t *testing.T) {
    // Property: reverse(reverse(s)) == s
    rapid.Check(t, func(t *rapid.T) {
        s := rapid.String().Draw(t, "s")
        if reverse(reverse(s)) != s {
            t.Fatalf("involution violated for %q", s)
        }
    })
}
```

## Common Test Structures

### Table-Driven Tests (Go)

```go
tests := map[string]struct {
    input    InputType
    want     OutputType
    wantErr  bool
}{
    "descriptive name": {input: x, want: y},
}

for name, tc := range tests {
    t.Run(name, func(t *testing.T) {
        got, err := Function(tc.input)
        if (err != nil) != tc.wantErr {
            t.Errorf("error = %v, wantErr %v", err, tc.wantErr)
            return
        }
        if got != tc.want {
            t.Errorf("got %v, want %v", got, tc.want)
        }
    })
}
```

### Parallel Tests

```go
for name, tc := range tests {
    tc := tc // capture for parallel
    t.Run(name, func(t *testing.T) {
        t.Parallel()
        // test body
    })
}
```

## Quality Checklist

Before finalizing tests:

```
Test Quality Check:
- [ ] Each test has a clear, descriptive name
- [ ] Tests are independent (no shared mutable state)
- [ ] Error cases are covered
- [ ] Boundary values are tested
- [ ] Tests run quickly (<100ms each)
- [ ] No test smells (duplicate setup, magic numbers)
- [ ] Mutation score >80% for critical code
```

## Detailed Guides

**Complete technique reference**: See [TECHNIQUES.md](references/TECHNIQUES.md)
**Common bug patterns**: See [BUG-PATTERNS.md](references/BUG-PATTERNS.md)
**Go-specific testing**: See [GO-TESTING.md](references/GO-TESTING.md)
**Testing heuristics**: See [HEURISTICS.md](references/HEURISTICS.md)
