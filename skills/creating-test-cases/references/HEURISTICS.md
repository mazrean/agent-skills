# Testing Heuristics and Mnemonics

Mental shortcuts and checklists for comprehensive testing.

## RCRCRC - Regression Test Prioritization

*By Karen N. Johnson*

Prioritize regression testing focus areas:

| Letter | Focus | Questions |
|--------|-------|-----------|
| **R**ecent | Newly added/changed code | What features were added recently? What code changed? |
| **C**ore | Critical functionality | What does this system fundamentally do? What must always work? |
| **R**isk | High-risk areas | What's complex? What uses new technology? What integrates externally? |
| **C**onfiguration | Environment-dependent | What changes across environments? DB connections? API keys? |
| **R**epaired | Recently fixed bugs | What bugs were fixed? Test regressions around fixes. |
| **C**hronic | Frequently failing areas | What keeps breaking? What has history of bugs? |

**Usage:**
```
Regression Test Planning for v2.1 Release:

Recent:
- [ ] New OAuth2 login flow
- [ ] Updated payment processing

Core:
- [ ] User registration
- [ ] Checkout and payment
- [ ] Order fulfillment

Risk:
- [ ] New third-party payment API
- [ ] Database migration scripts

Configuration:
- [ ] Production DB connection
- [ ] Payment gateway keys

Repaired:
- [ ] #1234 - Cart calculation bug
- [ ] #1256 - Session timeout issue

Chronic:
- [ ] Image upload module
- [ ] Email notification service
```

## SFDIPOT (San Francisco Depot)

*By James Bach*

Categories of things to test:

| Letter | Category | What to Consider |
|--------|----------|------------------|
| **S**tructure | Internal design | Components, modules, dependencies, code paths |
| **F**unction | What it does | Features, capabilities, error handling |
| **D**ata | Information flow | Input, output, storage, transformations |
| **I**nterfaces | Connection points | APIs, UIs, files, protocols |
| **P**latform | Environment | OS, browser, hardware, network |
| **O**perations | How it's used | User workflows, deployment, maintenance |
| **T**ime | Temporal aspects | Timing, concurrency, scheduling, history |

**Example Application:**

```
Testing an E-commerce Checkout:

Structure:
- Payment service integration
- Order database schema
- Cart session management

Function:
- Add/remove items
- Apply discounts
- Calculate totals
- Process payment
- Generate confirmation

Data:
- Product catalog
- User profiles
- Payment credentials
- Order records

Interfaces:
- Web UI forms
- Payment gateway API
- Email service
- Mobile app endpoints

Platform:
- Desktop browsers
- Mobile browsers
- iOS/Android apps
- Different networks

Operations:
- Guest checkout vs registered
- Cart abandonment/recovery
- Order modification
- Refund processing

Time:
- Session timeout
- Payment processing time
- Concurrent checkouts
- Sale price expiration
```

## HTSM - Heuristic Test Strategy Model

*By James Bach*

Framework for developing test strategy:

### Project Environment
- Resources (people, tools, equipment)
- Schedule and deadlines
- Test environment
- Organizational culture

### Product Elements
- Structure (architecture, components)
- Functions (capabilities)
- Data (inputs, outputs, states)
- Interfaces (APIs, UIs)
- Operations (how it's used)

### Quality Criteria
- Capability - Does it do what it should?
- Reliability - Does it work consistently?
- Usability - Is it easy to use?
- Charisma - Is it pleasant to use?
- Security - Is it protected?
- Scalability - Does it handle growth?
- Compatibility - Does it work with other things?
- Performance - Is it fast enough?
- Installability - Is it easy to set up?
- Maintainability - Is it easy to update?

### Test Techniques
- Function testing
- Domain testing
- Stress testing
- Flow testing
- Claims testing
- User testing
- Risk testing
- Automatic testing

## FEW HICCUPPS - Consistency Oracles

*By Michael Bolton and James Bach*

Oracles to identify potential problems:

| Letter | Oracle | Question |
|--------|--------|----------|
| **F**amiliarity | Prior knowledge | Does it match what I know from similar systems? |
| **E**xplainability | Documentation | Can its behavior be explained? |
| **W**orld | Real world | Does it match real-world expectations? |
| **H**istory | Past behavior | Is it consistent with its previous behavior? |
| **I**mage | Brand | Does it match the company's image/standards? |
| **C**omparable products | Competition | How do similar products behave? |
| **C**laims | Specifications | Does it match what was promised/specified? |
| **U**ser expectations | Audience | Does it match what users would expect? |
| **P**urpose | Goals | Does it fulfill its intended purpose? |
| **P**roduct | Internal consistency | Is it consistent with itself? |
| **S**tatutes | Regulations | Does it comply with laws and standards? |

## CRUD - Data Operations

Test all data operations:

| Operation | What to Test |
|-----------|--------------|
| **C**reate | Valid creation, duplicate prevention, required fields, defaults |
| **R**ead | Retrieval, filtering, pagination, empty results |
| **U**pdate | Partial update, concurrent updates, validation on update |
| **D**elete | Soft/hard delete, cascade behavior, deletion of non-existent |

**Extended CRUD+:**
- List/Search (with filters, sorting)
- Bulk operations
- Import/Export

## ZOMBIE - Boundary and Zero Cases

*By James Grenning*

| Letter | Test |
|--------|------|
| **Z**ero | Zero values, empty, null, none |
| **O**ne | Single item, first occurrence |
| **M**any | Multiple items, typical use |
| **B**oundary | Edge values, limits |
| **I**nterface | Boundaries between components |
| **E**xceptions | Error conditions, unexpected inputs |

**Example:**
```go
tests := map[string]struct {
    items []Item
    desc  string
}{
    "zero items":     {[]Item{}, "empty collection"},
    "one item":       {[]Item{item1}, "single element"},
    "many items":     {[]Item{item1, item2, item3}, "typical"},
    "boundary items": {make([]Item, MaxItems), "at limit"},
    "over boundary":  {make([]Item, MaxItems+1), "exceeds limit"},
}
```

## CORRECT - Boundary Conditions

| Letter | Boundary | What to Check |
|--------|----------|---------------|
| **C**onformance | Format/structure | Does it match expected format? |
| **O**rdering | Sequence | Is order preserved/correct? |
| **R**ange | Value limits | Min/max values respected? |
| **R**eference | External dependencies | What if references are missing/broken? |
| **E**xistence | Presence/absence | Null, empty, missing |
| **C**ardinality | Counts | Zero, one, many |
| **T**ime | Temporal | Ordering, timeouts, concurrency |

## INVEST - Good Test Properties

Characteristics of good tests:

| Letter | Property | Description |
|--------|----------|-------------|
| **I**ndependent | Isolation | Tests don't depend on each other |
| **N**amed well | Clarity | Name describes what's being tested |
| **V**aluable | Purpose | Tests something important |
| **E**xhaustive | Coverage | Covers edge cases |
| **S**mall | Focused | Tests one thing |
| **T**imely | Speed | Runs quickly |

## Error Guessing Checklist

Common areas to target:

### Input Values
- [ ] Null/nil
- [ ] Empty string ""
- [ ] Empty collection []
- [ ] Single character
- [ ] Very long strings
- [ ] Special characters (', ", <, >, &, \, /)
- [ ] Unicode characters
- [ ] Whitespace only
- [ ] Leading/trailing whitespace

### Numeric Values
- [ ] Zero
- [ ] Negative numbers
- [ ] Very large numbers (MAX_INT)
- [ ] Very small numbers (MIN_INT)
- [ ] Floating point precision edge cases
- [ ] NaN, Infinity

### Time and Dates
- [ ] Epoch (1970-01-01)
- [ ] Far future dates
- [ ] Far past dates
- [ ] Leap years (Feb 29)
- [ ] Month/year boundaries
- [ ] DST transitions
- [ ] Different time zones

### Files and Resources
- [ ] File doesn't exist
- [ ] File is empty
- [ ] File is very large
- [ ] File is locked
- [ ] No read/write permission
- [ ] Invalid file path
- [ ] Directory instead of file

### Network and Connections
- [ ] Connection timeout
- [ ] Connection refused
- [ ] Slow response
- [ ] Partial data received
- [ ] Invalid response format
- [ ] Authentication failure

### State and Concurrency
- [ ] Concurrent access
- [ ] Race conditions
- [ ] Interrupted operation
- [ ] Retry scenarios
- [ ] State after error

## Testing Mnemonics Quick Reference

| Mnemonic | Purpose | Key Points |
|----------|---------|------------|
| RCRCRC | Regression priority | Recent, Core, Risk, Config, Repaired, Chronic |
| SFDIPOT | Test categories | Structure, Function, Data, Interface, Platform, Operations, Time |
| ZOMBIE | Boundary cases | Zero, One, Many, Boundary, Interface, Exception |
| CRUD | Data operations | Create, Read, Update, Delete |
| CORRECT | Boundaries | Conformance, Ordering, Range, Reference, Existence, Cardinality, Time |
| FEW HICCUPPS | Oracles | Familiar, Explainable, World, History, Image, Comparable, Claims, User, Purpose, Product, Statutes |

## Applying Heuristics in Practice

1. **Start with RCRCRC** to prioritize what to test
2. **Use SFDIPOT** to ensure coverage breadth
3. **Apply ZOMBIE** to each feature for boundary cases
4. **Check CRUD** for any data operations
5. **Use FEW HICCUPPS** when evaluating results
6. **Apply error guessing checklist** for each input type

**Example Workflow:**

```
Testing User Registration Feature:

1. RCRCRC Analysis:
   - Recent: Yes (new feature) ✓ High priority
   - Core: Yes (fundamental) ✓ Must test thoroughly
   - Risk: Uses email service ✓ Test integration

2. SFDIPOT Coverage:
   - Structure: Registration service, User repository
   - Function: Create account, Validate input, Send email
   - Data: Email, password, name
   - Interface: Web form, API endpoint
   - Platform: Web, mobile
   - Operations: Normal flow, password reset
   - Time: Confirmation expiry

3. ZOMBIE for Email Input:
   - Zero: Empty email → Should error
   - One: Single char email → Should error
   - Many: Multiple emails → N/A (single input)
   - Boundary: Max length email → Test
   - Interface: Email vs username → Clear distinction
   - Exception: Invalid format → Should error

4. CRUD Tests:
   - Create: New user registration
   - Read: Login, profile view
   - Update: Change email/password
   - Delete: Account deletion

5. Error Guessing:
   - Duplicate email → Appropriate error
   - SQL injection in email → Sanitized
   - Very long password → Handled
   - Special chars in name → Handled
```
