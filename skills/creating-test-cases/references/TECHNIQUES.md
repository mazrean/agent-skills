# Test Design Techniques Reference

Comprehensive guide to systematic test design techniques.

## Specification-Based (Black-Box) Techniques

### Equivalence Partitioning (EP)

Divides input domain into partitions where all values in a partition should be treated identically.

**Principle:** If one value in a partition works, all others should. If one fails, all should fail.

**Process:**
1. Identify input variables and their domains
2. Partition each domain into equivalence classes
3. Include both valid and invalid partitions
4. Select one representative value from each partition

**Example: Password Validation**

```
Input: password (string)
Rules: 8-20 chars, must have uppercase, lowercase, digit

Equivalence Classes:
┌─────────────────────────────────────────────────────────┐
│ Length Partitions                                       │
├─────────────────────────────────────────────────────────┤
│ Invalid: length < 8    │ "abc1A"     (too short)       │
│ Valid:   8 <= len <= 20│ "Password1" (valid length)    │
│ Invalid: length > 20   │ "A"*21      (too long)        │
├─────────────────────────────────────────────────────────┤
│ Character Requirements                                  │
├─────────────────────────────────────────────────────────┤
│ Missing uppercase      │ "password1"                   │
│ Missing lowercase      │ "PASSWORD1"                   │
│ Missing digit          │ "Passwordx"                   │
│ All requirements met   │ "Password1"                   │
└─────────────────────────────────────────────────────────┘
```

### Boundary Value Analysis (BVA)

Tests at the edges of equivalence partitions where bugs most commonly occur.

**Principle:** Most bugs cluster at boundaries due to off-by-one errors, incorrect operators (< vs <=), etc.

**Standard BVA values:**
- Minimum value
- Just above minimum (min + 1)
- Just below maximum (max - 1)
- Maximum value
- Just outside boundaries (min - 1, max + 1)

**Example: Age Input (valid: 18-65)**

```
Boundary Points:
     17     18     19          64     65     66
      │      │      │           │      │      │
      ▼      ▼      ▼           ▼      ▼      ▼
  ────┼──────┼──────┼───────────┼──────┼──────┼────
      │ Invalid │    Valid      │Invalid│

Test values: 17, 18, 19, 64, 65, 66
Plus extremes: 0, -1, MAX_INT
```

**Robustness BVA:** Also test:
- Empty/null inputs
- Type boundaries (MAX_INT, MIN_INT)
- Floating-point edge cases (0.0, -0.0, Inf, NaN)

### Decision Table Testing

For complex business logic with multiple conditions affecting outcomes.

**Process:**
1. List all conditions (inputs/causes)
2. List all actions (outputs/effects)
3. Create columns for condition combinations
4. Determine applicable actions for each combination
5. Simplify by merging rules with same outcomes

**Example: Shipping Cost Calculation**

| Conditions          | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 |
|---------------------|----|----|----|----|----|----|----|----|
| Prime member?       | Y  | Y  | Y  | Y  | N  | N  | N  | N  |
| Order >= $50?       | Y  | Y  | N  | N  | Y  | Y  | N  | N  |
| Express shipping?   | Y  | N  | Y  | N  | Y  | N  | Y  | N  |
| **Actions**         |    |    |    |    |    |    |    |    |
| Free standard       |    | X  |    |    |    |    |    |    |
| $5.99 standard      |    |    |    | X  |    | X  |    |    |
| $9.99 standard      |    |    |    |    |    |    |    | X  |
| $9.99 express       | X  |    | X  |    |    |    |    |    |
| $14.99 express      |    |    |    |    | X  |    | X  |    |

**Simplified (collapsing equivalent rules):**

```go
tests := []struct {
    name     string
    prime    bool
    amount   float64
    express  bool
    wantCost float64
}{
    {"prime, $50+, express", true, 100, true, 9.99},
    {"prime, $50+, standard", true, 100, false, 0},
    {"prime, <$50, express", true, 30, true, 9.99},
    {"prime, <$50, standard", true, 30, false, 5.99},
    {"non-prime, $50+, express", false, 100, true, 14.99},
    // ... etc
}
```

### State Transition Testing

For systems with defined states and transitions.

**Components:**
- **States:** Distinct conditions the system can be in
- **Transitions:** Changes from one state to another
- **Events:** Triggers for transitions
- **Guards:** Conditions that must be true for transition
- **Actions:** Operations performed during transition

**Example: Order State Machine**

```
     ┌─────────────────────────────────────────────┐
     │                                             │
     ▼                                             │
 ┌───────┐  create   ┌─────────┐  pay    ┌──────┐ │
 │ Draft │──────────▶│ Pending │────────▶│ Paid │ │
 └───────┘           └─────────┘         └──────┘ │
     │                    │                  │     │
     │ cancel             │ cancel           │ ship│
     │                    │                  │     │
     ▼                    ▼                  ▼     │
 ┌───────────────────────────────────────────────┐│
 │              Cancelled                        ││
 └───────────────────────────────────────────────┘│
                                                  │
                                            ┌─────┴───┐
                                            │ Shipped │
                                            └─────────┘
```

**Test Coverage Levels:**

1. **All States:** Visit every state at least once
2. **All Transitions:** Execute every valid transition
3. **Invalid Transitions:** Verify invalid transitions are rejected
4. **Transition Sequences:** Test common paths end-to-end

```go
tests := []struct {
    name         string
    initial      State
    event        Event
    wantState    State
    wantError    bool
}{
    // Valid transitions
    {"draft->pending", Draft, Create, Pending, false},
    {"pending->paid", Pending, Pay, Paid, false},
    {"paid->shipped", Paid, Ship, Shipped, false},

    // Invalid transitions
    {"draft->shipped", Draft, Ship, Draft, true},
    {"shipped->pending", Shipped, Create, Shipped, true},

    // Cancellation from various states
    {"cancel from draft", Draft, Cancel, Cancelled, false},
    {"cancel from pending", Pending, Cancel, Cancelled, false},
    {"cancel from shipped", Shipped, Cancel, Shipped, true},
}
```

### Pairwise (All-Pairs) Testing

Reduces test combinations by ensuring every pair of parameter values appears together at least once.

**Why it works:** Most bugs are caused by single factors or pairs of factors, not higher-order combinations.

**Example: Configuration Testing**

```
Parameters:
- OS: Windows, macOS, Linux
- Browser: Chrome, Firefox, Safari
- Screen: 1080p, 4K
- Theme: Light, Dark

Full combinations: 3 × 3 × 2 × 2 = 36 tests
Pairwise coverage: ~12 tests (67% reduction)

Pairwise test set:
| # | OS      | Browser | Screen | Theme |
|---|---------|---------|--------|-------|
| 1 | Windows | Chrome  | 1080p  | Light |
| 2 | Windows | Firefox | 4K     | Dark  |
| 3 | Windows | Safari  | 1080p  | Dark  |
| 4 | macOS   | Chrome  | 4K     | Dark  |
| 5 | macOS   | Firefox | 1080p  | Light |
| 6 | macOS   | Safari  | 4K     | Light |
| 7 | Linux   | Chrome  | 1080p  | Dark  |
| 8 | Linux   | Firefox | 4K     | Light |
| 9 | Linux   | Safari  | 4K     | Dark  |
```

**Tools:**
- PICT (Microsoft): `pict model.txt`
- AllPairs
- Hexawise (commercial)

### Use Case Testing

Tests end-to-end user scenarios through the system.

**Structure:**
1. **Preconditions:** Initial system state
2. **Main flow:** Happy path steps
3. **Alternative flows:** Variations
4. **Exception flows:** Error handling
5. **Postconditions:** Expected final state

**Example: User Registration**

```
Use Case: Register New User

Preconditions:
- User is not logged in
- Email is not already registered

Main Flow (Happy Path):
1. User enters email, password, name
2. System validates input
3. System creates account
4. System sends confirmation email
5. User clicks confirmation link
6. Account is activated

Alternative Flows:
- 2a. Password doesn't meet requirements
  - System shows specific error
  - Return to step 1
- 4a. Email delivery fails
  - System queues for retry
  - Show "check spam folder" message

Exception Flows:
- 2b. Email already registered
  - Show "account exists" message
  - Offer password reset
- 5a. Confirmation link expired
  - Allow resend confirmation
```

## Structure-Based (White-Box) Techniques

### Statement Coverage

**Goal:** Execute every statement at least once.

```go
func calculate(a, b int) int {
    result := 0           // S1
    if a > 0 {
        result = a * 2    // S2
    }
    if b > 0 {
        result += b       // S3
    }
    return result         // S4
}

// 100% statement coverage:
// Test 1: a=1, b=1 → covers S1, S2, S3, S4
```

### Branch/Decision Coverage

**Goal:** Execute every branch (true/false) of every decision.

```go
func calculate(a, b int) int {
    result := 0
    if a > 0 {           // Decision 1
        result = a * 2   // Branch 1T
    }                    // Branch 1F (implicit)
    if b > 0 {           // Decision 2
        result += b      // Branch 2T
    }                    // Branch 2F (implicit)
    return result
}

// 100% branch coverage:
// Test 1: a=1, b=1 → D1=T, D2=T
// Test 2: a=0, b=0 → D1=F, D2=F
```

### Condition Coverage

**Goal:** Each atomic condition evaluates to both true and false.

```go
func check(a, b bool) bool {
    return a && b  // Condition: a, Condition: b
}

// 100% condition coverage:
// Test 1: a=T, b=T → a=T, b=T
// Test 2: a=F, b=F → a=F, b=F
```

**Note:** Condition coverage doesn't guarantee decision coverage!

### MC/DC (Modified Condition/Decision Coverage)

**Goal:** Each condition independently affects the decision outcome.

**Requirements:**
1. Every decision takes all possible outcomes
2. Every condition takes all possible outcomes
3. Each condition shown to independently affect decision

```go
func authorize(admin bool, owner bool) bool {
    return admin || owner
}

// MC/DC test set:
// | admin | owner | result | Shows independence of: |
// |-------|-------|--------|------------------------|
// |   T   |   F   |   T    | admin (compare with 2) |
// |   F   |   F   |   F    | admin (compare with 1) |
// |   F   |   T   |   T    | owner (compare with 2) |

// 3 tests achieve MC/DC for 2 conditions
// Formula: n+1 tests for n conditions (minimum)
```

### Path Coverage

**Goal:** Execute every unique path through the code.

**Caution:** Path explosion with loops. Use basis paths or limit iterations.

```go
func process(a, b, c bool) {
    if a { /* P1 */ }  // 2 paths
    if b { /* P2 */ }  // 2 paths
    if c { /* P3 */ }  // 2 paths
}

// Total paths: 2 × 2 × 2 = 8
// Basis paths (cyclomatic complexity + 1): 4
```

## Experience-Based Techniques

### Error Guessing

Intuition-based testing targeting likely defect areas.

**Common targets:**

| Category | What to Test |
|----------|--------------|
| Zero/Empty | 0, "", [], nil, null |
| Boundaries | MAX/MIN values, size limits |
| Format | Invalid dates, malformed JSON, encoding |
| Resources | Disk full, memory exhausted, timeout |
| Concurrency | Race conditions, deadlocks |
| Security | Injection, XSS, CSRF |
| Network | Disconnection, latency, packet loss |

### Exploratory Testing

Simultaneous learning, test design, and execution.

**Session structure:**
1. Charter: Define focus area and time limit
2. Explore: Navigate and test the system
3. Document: Record findings and coverage
4. Debrief: Summarize insights and bugs found

**Heuristics to apply:**
- Follow the data flow
- Try unexpected sequences
- Look for inconsistencies
- Test with extreme values
- Interrupt operations midway

### Risk-Based Testing

Prioritize testing based on risk = probability × impact.

**Risk factors:**
- Complexity of code
- Frequency of changes
- Criticality to business
- Past defect history
- New technology/team

## Advanced Techniques

### Mutation Testing

Evaluate test suite quality by introducing code mutations.

**Process:**
1. Make small code changes (mutants)
2. Run test suite against each mutant
3. Check if tests detect (kill) mutants
4. Calculate mutation score

**Common mutation operators:**

| Operator | Original | Mutant |
|----------|----------|--------|
| AOR | a + b | a - b, a * b, a / b |
| ROR | a > b | a >= b, a < b, a == b |
| LCR | a && b | a \|\| b |
| UOI | a | -a, !a |
| SDL | statement | (deleted) |

**Target:** Mutation score > 80%

### Property-Based Testing

Test properties/invariants across many random inputs.

**Common properties:**

| Property | Description |
|----------|-------------|
| Roundtrip | decode(encode(x)) == x |
| Idempotent | f(f(x)) == f(x) |
| Commutative | f(a,b) == f(b,a) |
| Associative | f(f(a,b),c) == f(a,f(b,c)) |
| Invariant | property always holds |

**Example with rapid (Go):**

```go
func TestSort_Preserves_Length(t *testing.T) {
    rapid.Check(t, func(t *rapid.T) {
        input := rapid.SliceOf(rapid.Int()).Draw(t, "input")
        output := sort(input)
        if len(output) != len(input) {
            t.Fatalf("length changed: %d -> %d", len(input), len(output))
        }
    })
}
```

### Metamorphic Testing

Verify relationships between outputs when inputs are transformed.

**Use when:** No test oracle (can't easily determine correct output).

**Example: Search engine**

```
Metamorphic Relations:
1. Subset: search("A B") results ⊆ search("A") results
2. Ordering: search("A") same results as search("a")
3. Additive: search("A OR B") = search("A") ∪ search("B")
```

### Fuzzing

Generate random/malformed inputs to find crashes and vulnerabilities.

**Types:**
1. **Dumb fuzzing:** Pure random data
2. **Smart fuzzing:** Grammar-aware generation
3. **Coverage-guided:** Use coverage to guide generation

**Go native fuzzing:**

```go
func FuzzParseJSON(f *testing.F) {
    // Seed corpus
    f.Add([]byte(`{"key": "value"}`))
    f.Add([]byte(`[]`))

    f.Fuzz(func(t *testing.T, data []byte) {
        var v interface{}
        if err := json.Unmarshal(data, &v); err != nil {
            return // Invalid input, skip
        }
        // Additional invariant checks
    })
}
```

## Technique Selection Guide

| Situation | Recommended Techniques |
|-----------|------------------------|
| New feature | EP + BVA + Use Case |
| Complex logic | Decision Tables |
| Stateful system | State Transition |
| Configuration | Pairwise |
| Security-critical | Fuzzing + Error Guessing |
| High reliability | MC/DC + Mutation |
| Unknown domain | Exploratory |
| Many parameters | Property-Based |
| Regression | Risk-Based + RCRCRC |
