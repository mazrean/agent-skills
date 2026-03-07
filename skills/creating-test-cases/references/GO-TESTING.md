# Go Testing Patterns

Go-specific testing techniques, idioms, and best practices.

## Table-Driven Tests

The idiomatic Go approach for testing multiple cases.

### Basic Structure

```go
func TestFunction(t *testing.T) {
    tests := []struct {
        name    string
        input   InputType
        want    OutputType
        wantErr bool
    }{
        {"descriptive name", input1, want1, false},
        {"another case", input2, want2, false},
        {"error case", badInput, zeroVal, true},
    }

    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
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
}
```

### Map-Based Tests (Preferred)

Using maps provides better IDE support and random iteration order (catches order dependencies):

```go
func TestFunction(t *testing.T) {
    tests := map[string]struct {
        input   InputType
        want    OutputType
        wantErr bool
    }{
        "valid input": {
            input: validValue,
            want:  expectedResult,
        },
        "boundary value": {
            input: boundaryValue,
            want:  boundaryResult,
        },
        "error case": {
            input:   invalidValue,
            wantErr: true,
        },
    }

    for name, tc := range tests {
        t.Run(name, func(t *testing.T) {
            got, err := Function(tc.input)

            if (err != nil) != tc.wantErr {
                t.Fatalf("error = %v, wantErr %v", err, tc.wantErr)
            }

            if !tc.wantErr && got != tc.want {
                t.Errorf("got %v, want %v", got, tc.want)
            }
        })
    }
}
```

### Parallel Tests

```go
func TestFunctionParallel(t *testing.T) {
    tests := map[string]struct {
        input InputType
        want  OutputType
    }{
        "case1": {input1, want1},
        "case2": {input2, want2},
    }

    for name, tc := range tests {
        tc := tc // Capture for parallel execution (Go < 1.22)
        t.Run(name, func(t *testing.T) {
            t.Parallel() // Mark as parallel

            got := Function(tc.input)
            if got != tc.want {
                t.Errorf("got %v, want %v", got, tc.want)
            }
        })
    }
}
```

**Note:** Go 1.22+ fixes the loop variable capture issue, but `tc := tc` remains safe.

## Test Helpers

### Setup and Teardown

```go
func TestWithSetup(t *testing.T) {
    // Setup
    db := setupTestDB(t)
    t.Cleanup(func() {
        db.Close()
    })

    // Test cases use db
    t.Run("case1", func(t *testing.T) {
        // Uses db
    })
}

// Helper function that marks itself as helper
func setupTestDB(t *testing.T) *sql.DB {
    t.Helper() // Errors report caller's line, not this function's

    db, err := sql.Open("sqlite3", ":memory:")
    if err != nil {
        t.Fatalf("failed to open db: %v", err)
    }
    return db
}
```

### Temporary Files/Directories

```go
func TestWithTempFile(t *testing.T) {
    // TempDir is automatically cleaned up
    dir := t.TempDir()

    // Create test file
    path := filepath.Join(dir, "test.txt")
    if err := os.WriteFile(path, []byte("content"), 0644); err != nil {
        t.Fatalf("failed to write file: %v", err)
    }

    // Test with the file
    result, err := processFile(path)
    if err != nil {
        t.Errorf("unexpected error: %v", err)
    }
}
```

### Test Fixtures

```go
// testdata/ directory is ignored by go build

func TestWithFixture(t *testing.T) {
    // Read fixture
    input, err := os.ReadFile("testdata/input.json")
    if err != nil {
        t.Fatalf("failed to read fixture: %v", err)
    }

    expected, err := os.ReadFile("testdata/expected.json")
    if err != nil {
        t.Fatalf("failed to read expected: %v", err)
    }

    got := process(input)
    if !bytes.Equal(got, expected) {
        t.Errorf("output mismatch:\ngot:  %s\nwant: %s", got, expected)
    }
}
```

## Golden Files

Test against pre-recorded expected output:

```go
var update = flag.Bool("update", false, "update golden files")

func TestGolden(t *testing.T) {
    input := loadTestInput(t)
    got := process(input)

    goldenPath := "testdata/golden.txt"

    if *update {
        if err := os.WriteFile(goldenPath, got, 0644); err != nil {
            t.Fatalf("failed to update golden file: %v", err)
        }
        return
    }

    want, err := os.ReadFile(goldenPath)
    if err != nil {
        t.Fatalf("failed to read golden file: %v", err)
    }

    if !bytes.Equal(got, want) {
        t.Errorf("output differs from golden file\ngot:\n%s\nwant:\n%s", got, want)
    }
}
```

Usage:
```bash
go test -update ./...  # Update golden files
go test ./...          # Compare against golden files
```

## Subtests for BDD-Style

```go
func TestUserService(t *testing.T) {
    svc := NewUserService()

    t.Run("Create", func(t *testing.T) {
        t.Run("with valid data", func(t *testing.T) {
            user, err := svc.Create(validUserData)
            if err != nil {
                t.Fatalf("unexpected error: %v", err)
            }
            if user.ID == "" {
                t.Error("expected user ID to be set")
            }
        })

        t.Run("with duplicate email", func(t *testing.T) {
            _, err := svc.Create(duplicateEmailData)
            if !errors.Is(err, ErrDuplicateEmail) {
                t.Errorf("expected ErrDuplicateEmail, got %v", err)
            }
        })
    })

    t.Run("Get", func(t *testing.T) {
        t.Run("existing user", func(t *testing.T) {
            // ...
        })

        t.Run("non-existent user", func(t *testing.T) {
            // ...
        })
    })
}
```

## Testing Error Cases

### Checking Error Types

```go
func TestErrorHandling(t *testing.T) {
    tests := map[string]struct {
        input   string
        wantErr error
    }{
        "not found": {
            input:   "missing",
            wantErr: ErrNotFound,
        },
        "invalid format": {
            input:   "bad-format",
            wantErr: ErrInvalidFormat,
        },
    }

    for name, tc := range tests {
        t.Run(name, func(t *testing.T) {
            _, err := Function(tc.input)

            if !errors.Is(err, tc.wantErr) {
                t.Errorf("error = %v, want %v", err, tc.wantErr)
            }
        })
    }
}
```

### Testing Error Messages

```go
func TestErrorMessage(t *testing.T) {
    _, err := Function("bad-input")

    if err == nil {
        t.Fatal("expected error")
    }

    if !strings.Contains(err.Error(), "expected substring") {
        t.Errorf("error message should contain context: %v", err)
    }
}
```

### Testing Panics

```go
func TestPanic(t *testing.T) {
    defer func() {
        if r := recover(); r == nil {
            t.Error("expected panic")
        }
    }()

    functionThatPanics()
}

// Using testify
func TestPanicWithTestify(t *testing.T) {
    assert.Panics(t, func() {
        functionThatPanics()
    })
}
```

## Mocking and Interfaces

### Interface-Based Mocking

```go
// Define interface for dependencies
type UserRepository interface {
    GetByID(id string) (*User, error)
    Save(user *User) error
}

// Production implementation
type PostgresUserRepo struct { /* ... */ }

// Test mock
type MockUserRepo struct {
    GetByIDFunc func(id string) (*User, error)
    SaveFunc    func(user *User) error
}

func (m *MockUserRepo) GetByID(id string) (*User, error) {
    return m.GetByIDFunc(id)
}

func (m *MockUserRepo) Save(user *User) error {
    return m.SaveFunc(user)
}

// In test
func TestUserService_GetUser(t *testing.T) {
    mockRepo := &MockUserRepo{
        GetByIDFunc: func(id string) (*User, error) {
            if id == "123" {
                return &User{ID: "123", Name: "Test"}, nil
            }
            return nil, ErrNotFound
        },
    }

    svc := NewUserService(mockRepo)

    user, err := svc.GetUser("123")
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if user.Name != "Test" {
        t.Errorf("got name %q, want %q", user.Name, "Test")
    }
}
```

## Fuzzing

Go 1.18+ native fuzzing:

```go
func FuzzParseJSON(f *testing.F) {
    // Add seed corpus
    f.Add([]byte(`{}`))
    f.Add([]byte(`{"key": "value"}`))
    f.Add([]byte(`[1, 2, 3]`))
    f.Add([]byte(`null`))

    f.Fuzz(func(t *testing.T, data []byte) {
        var v interface{}

        // Just checking it doesn't panic
        err := json.Unmarshal(data, &v)
        if err != nil {
            return // Invalid JSON is expected
        }

        // Round-trip test
        encoded, err := json.Marshal(v)
        if err != nil {
            t.Errorf("failed to re-encode: %v", err)
        }

        var v2 interface{}
        if err := json.Unmarshal(encoded, &v2); err != nil {
            t.Errorf("failed to decode re-encoded: %v", err)
        }
    })
}
```

Run fuzzing:
```bash
go test -fuzz=FuzzParseJSON -fuzztime=30s
```

## Benchmarking

```go
func BenchmarkFunction(b *testing.B) {
    input := prepareInput()

    b.ResetTimer() // Exclude setup time

    for i := 0; i < b.N; i++ {
        Function(input)
    }
}

// Table-driven benchmarks
func BenchmarkFunctionSizes(b *testing.B) {
    sizes := []int{10, 100, 1000, 10000}

    for _, size := range sizes {
        b.Run(fmt.Sprintf("size=%d", size), func(b *testing.B) {
            input := generateInput(size)
            b.ResetTimer()

            for i := 0; i < b.N; i++ {
                Function(input)
            }
        })
    }
}

// Memory allocation tracking
func BenchmarkAllocs(b *testing.B) {
    b.ReportAllocs()

    for i := 0; i < b.N; i++ {
        Function()
    }
}
```

Run benchmarks:
```bash
go test -bench=. -benchmem
```

## Race Detection

```bash
go test -race ./...
```

Write tests that exercise concurrent code:

```go
func TestConcurrentAccess(t *testing.T) {
    cache := NewCache()
    var wg sync.WaitGroup

    // Concurrent writes
    for i := 0; i < 100; i++ {
        wg.Add(1)
        go func(i int) {
            defer wg.Done()
            cache.Set(fmt.Sprintf("key%d", i), i)
        }(i)
    }

    // Concurrent reads
    for i := 0; i < 100; i++ {
        wg.Add(1)
        go func(i int) {
            defer wg.Done()
            cache.Get(fmt.Sprintf("key%d", i))
        }(i)
    }

    wg.Wait()
}
```

## Testing HTTP Handlers

```go
func TestHandler(t *testing.T) {
    handler := NewHandler()

    tests := map[string]struct {
        method     string
        path       string
        body       io.Reader
        wantStatus int
        wantBody   string
    }{
        "successful GET": {
            method:     "GET",
            path:       "/users/123",
            wantStatus: http.StatusOK,
            wantBody:   `{"id":"123"}`,
        },
        "not found": {
            method:     "GET",
            path:       "/users/999",
            wantStatus: http.StatusNotFound,
        },
        "invalid method": {
            method:     "DELETE",
            path:       "/users/123",
            wantStatus: http.StatusMethodNotAllowed,
        },
    }

    for name, tc := range tests {
        t.Run(name, func(t *testing.T) {
            req := httptest.NewRequest(tc.method, tc.path, tc.body)
            rec := httptest.NewRecorder()

            handler.ServeHTTP(rec, req)

            if rec.Code != tc.wantStatus {
                t.Errorf("status = %d, want %d", rec.Code, tc.wantStatus)
            }

            if tc.wantBody != "" && rec.Body.String() != tc.wantBody {
                t.Errorf("body = %q, want %q", rec.Body.String(), tc.wantBody)
            }
        })
    }
}
```

## Integration Tests

Separate integration tests with build tags:

```go
//go:build integration

package mypackage

import "testing"

func TestDatabaseIntegration(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test")
    }

    db := connectToRealDB()
    // ...
}
```

Run:
```bash
go test -tags=integration ./...
go test -short ./...  # Skip integration tests
```

## Test Coverage

```bash
# Generate coverage
go test -coverprofile=coverage.out ./...

# View in browser
go tool cover -html=coverage.out

# Check coverage percentage
go tool cover -func=coverage.out

# Fail if coverage below threshold
go test -coverprofile=coverage.out ./... && \
  go tool cover -func=coverage.out | grep total | awk '{if ($3+0 < 80) exit 1}'
```

## Best Practices Summary

| Practice | Description |
|----------|-------------|
| Use `t.Helper()` | Helpers report correct line numbers |
| Use `t.Cleanup()` | Cleanup runs even on failure |
| Use `t.TempDir()` | Auto-cleaned temporary directories |
| Use map-based tests | Better IDE support, catches order dependencies |
| Capture loop variables | `tc := tc` before `t.Parallel()` (Go < 1.22) |
| Use `t.Fatalf()` for setup | Stop test on setup failure |
| Use `t.Errorf()` for assertions | Continue checking other conditions |
| Name tests descriptively | `"returns error when input is empty"` |
| Keep tests independent | No shared mutable state |
| Run with `-race` | Catch race conditions |
