# Best Practices and Patterns

Common patterns and best practices for templ applications.

## Project Structure

### Recommended Layout

```
myapp/
├── cmd/
│   └── server/
│       └── main.go
├── internal/
│   ├── handlers/      # HTTP handlers
│   │   └── user.go
│   ├── services/      # Business logic
│   │   └── user.go
│   ├── db/            # Database access
│   │   └── user.go
│   └── models/        # Domain models
│       └── user.go
├── views/             # Templ components
│   ├── layouts/
│   │   └── base.templ
│   ├── pages/
│   │   ├── home.templ
│   │   └── user.templ
│   └── components/
│       ├── header.templ
│       ├── footer.templ
│       └── card.templ
├── static/
│   ├── css/
│   └── js/
├── go.mod
└── go.sum
```

### Onion Architecture

```
handlers → services → db
    ↓
  views (templ components)
```

- **handlers**: Process HTTP, call services, render views
- **services**: Business logic, no HTTP/HTML knowledge
- **db**: Data access
- **views**: Presentation only

## Layout Pattern

### Base Layout

```templ
// views/layouts/base.templ
package layouts

templ Base(title string) {
    <!DOCTYPE html>
    <html lang="en">
        <head>
            <meta charset="UTF-8"/>
            <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
            <title>{ title } | MyApp</title>
            <link rel="stylesheet" href="/static/css/style.css"/>
        </head>
        <body>
            @Header()
            <main class="container">
                { children... }
            </main>
            @Footer()
            <script src="/static/js/app.js"></script>
        </body>
    </html>
}
```

### Using Layout

```templ
// views/pages/home.templ
package pages

import "myapp/views/layouts"

templ HomePage(user User) {
    @layouts.Base("Home") {
        <h1>Welcome, { user.Name }!</h1>
        <p>This is the home page.</p>
    }
}
```

## View Models

Use view models to simplify templates:

```go
// internal/handlers/user.go
type UserPageViewModel struct {
    Name        string
    Email       string
    MemberSince string
    IsAdmin     bool
}

func NewUserPageViewModel(user models.User) UserPageViewModel {
    return UserPageViewModel{
        Name:        user.FirstName + " " + user.LastName,
        Email:       user.Email,
        MemberSince: user.CreatedAt.Format("January 2006"),
        IsAdmin:     user.Role == "admin",
    }
}

func (h *Handler) UserPage(w http.ResponseWriter, r *http.Request) {
    user := h.service.GetUser(r.Context(), id)
    vm := NewUserPageViewModel(user)
    pages.UserPage(vm).Render(r.Context(), w)
}
```

```templ
// views/pages/user.templ
templ UserPage(vm UserPageViewModel) {
    @layouts.Base(vm.Name) {
        <h1>{ vm.Name }</h1>
        <p>Email: { vm.Email }</p>
        <p>Member since: { vm.MemberSince }</p>
        if vm.IsAdmin {
            <span class="badge">Admin</span>
        }
    }
}
```

## Component Composition

### Reusable Components

```templ
// views/components/card.templ
templ Card(title string) {
    <div class="card">
        <div class="card-header">
            <h3>{ title }</h3>
        </div>
        <div class="card-body">
            { children... }
        </div>
    </div>
}

// views/components/button.templ
templ Button(text string, variant string) {
    <button class={ "btn", "btn-" + variant }>
        { text }
    </button>
}
```

### Usage

```templ
templ UserCard(user User) {
    @Card(user.Name) {
        <p>{ user.Email }</p>
        @Button("Edit", "primary")
        @Button("Delete", "danger")
    }
}
```

## Error Handling

### Custom Error Handler

```go
func errorHandler(r *http.Request, err error) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        log.Printf("Render error for %s: %v", r.URL.Path, err)

        w.WriteHeader(http.StatusInternalServerError)
        pages.ErrorPage("Something went wrong").Render(r.Context(), w)
    })
}

http.Handle("/", templ.Handler(
    Page(),
    templ.WithErrorHandler(errorHandler),
))
```

### Error Page

```templ
templ ErrorPage(message string) {
    @layouts.Base("Error") {
        <div class="error-container">
            <h1>Oops!</h1>
            <p>{ message }</p>
            <a href="/">Go Home</a>
        </div>
    }
}
```

## Form Handling

### Form Component

```templ
templ ContactForm(data FormData, errors map[string]string) {
    <form method="POST" action="/contact">
        <div class="form-group">
            <label for="name">Name</label>
            <input
                type="text"
                id="name"
                name="name"
                value={ data.Name }
                class={ templ.KV("is-invalid", errors["name"] != "") }
            />
            if err, ok := errors["name"]; ok {
                <span class="error">{ err }</span>
            }
        </div>

        <div class="form-group">
            <label for="email">Email</label>
            <input
                type="email"
                id="email"
                name="email"
                value={ data.Email }
                class={ templ.KV("is-invalid", errors["email"] != "") }
            />
            if err, ok := errors["email"]; ok {
                <span class="error">{ err }</span>
            }
        </div>

        <button type="submit">Send</button>
    </form>
}
```

### Handler

```go
func (h *Handler) Contact(w http.ResponseWriter, r *http.Request) {
    if r.Method == "GET" {
        pages.ContactPage(FormData{}, nil).Render(r.Context(), w)
        return
    }

    data := FormData{
        Name:  r.FormValue("name"),
        Email: r.FormValue("email"),
    }

    errors := validate(data)
    if len(errors) > 0 {
        pages.ContactPage(data, errors).Render(r.Context(), w)
        return
    }

    h.service.SendContact(data)
    http.Redirect(w, r, "/thank-you", http.StatusSeeOther)
}
```

## HTMX Integration

### Partial Updates

```templ
templ TodoList(todos []Todo) {
    <div id="todo-list">
        for _, todo := range todos {
            @TodoItem(todo)
        }
    </div>
}

templ TodoItem(todo Todo) {
    <div
        id={ "todo-" + todo.ID }
        class={ templ.KV("completed", todo.Done) }
    >
        <span>{ todo.Title }</span>
        <button
            hx-post={ "/todos/" + todo.ID + "/toggle" }
            hx-target={ "#todo-" + todo.ID }
            hx-swap="outerHTML"
        >
            Toggle
        </button>
        <button
            hx-delete={ "/todos/" + todo.ID }
            hx-target={ "#todo-" + todo.ID }
            hx-swap="delete"
        >
            Delete
        </button>
    </div>
}
```

### Handler for Partial

```go
func (h *Handler) ToggleTodo(w http.ResponseWriter, r *http.Request) {
    id := chi.URLParam(r, "id")
    todo := h.service.Toggle(id)

    // Return just the updated item
    components.TodoItem(todo).Render(r.Context(), w)
}
```

## Testing

### Component Testing

```go
func TestUserCard(t *testing.T) {
    user := User{Name: "John", Email: "john@example.com"}

    var buf bytes.Buffer
    err := UserCard(user).Render(context.Background(), &buf)

    assert.NoError(t, err)
    assert.Contains(t, buf.String(), "John")
    assert.Contains(t, buf.String(), "john@example.com")
}
```

### Snapshot Testing

```go
func TestHomePage(t *testing.T) {
    var buf bytes.Buffer
    HomePage(testData).Render(context.Background(), &buf)

    golden := filepath.Join("testdata", "home_page.golden.html")

    if *update {
        os.WriteFile(golden, buf.Bytes(), 0644)
    }

    expected, _ := os.ReadFile(golden)
    assert.Equal(t, string(expected), buf.String())
}
```
