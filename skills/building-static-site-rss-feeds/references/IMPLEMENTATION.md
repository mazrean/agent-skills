# RSS Feed Implementation Guide

Practical implementation examples for generating RSS feeds in static sites.

## Go Implementation with gorilla/feeds

### Installation

```bash
go get github.com/gorilla/feeds
```

### Basic Feed Generation

```go
package main

import (
    "os"
    "time"

    "github.com/gorilla/feeds"
)

func main() {
    now := time.Now()

    feed := &feeds.Feed{
        Title:       "My Blog",
        Link:        &feeds.Link{Href: "https://example.com"},
        Description: "Recent articles from my blog",
        Author:      &feeds.Author{Name: "John Doe", Email: "john@example.com"},
        Created:     now,
        Updated:     now,
    }

    feed.Items = []*feeds.Item{
        {
            Title:       "First Post",
            Link:        &feeds.Link{Href: "https://example.com/posts/first"},
            Description: "This is my first blog post.",
            Author:      &feeds.Author{Name: "John Doe"},
            Id:          "https://example.com/posts/first",
            Created:     time.Date(2026, 1, 15, 10, 0, 0, 0, time.UTC),
            Updated:     time.Date(2026, 1, 15, 10, 0, 0, 0, time.UTC),
        },
        {
            Title:       "Second Post",
            Link:        &feeds.Link{Href: "https://example.com/posts/second"},
            Description: "Another article about Go.",
            Id:          "https://example.com/posts/second",
            Created:     time.Date(2026, 1, 20, 14, 30, 0, 0, time.UTC),
        },
    }

    // Generate RSS 2.0
    rss, _ := feed.ToRss()
    os.WriteFile("public/feed.xml", []byte(rss), 0644)

    // Generate Atom 1.0
    atom, _ := feed.ToAtom()
    os.WriteFile("public/atom.xml", []byte(atom), 0644)

    // Generate JSON Feed
    json, _ := feed.ToJSON()
    os.WriteFile("public/feed.json", []byte(json), 0644)
}
```

### Full Content in Feeds

```go
item := &feeds.Item{
    Title:   "Article Title",
    Link:    &feeds.Link{Href: "https://example.com/article"},
    Id:      "https://example.com/article",
    Created: time.Now(),
    // Use Content for full article body
    Content: `<p>This is the full article content.</p>
              <p>It can include <strong>HTML</strong> formatting.</p>`,
    // Description for summary/excerpt
    Description: "A brief summary of the article.",
}
```

## Go Template-Based Generation

For custom control over XML output:

### RSS Template

```go
const rssTemplate = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>{{.Title}}</title>
    <link>{{.Link}}</link>
    <description>{{.Description}}</description>
    <language>{{.Language}}</language>
    <lastBuildDate>{{.LastBuildDate}}</lastBuildDate>
    <atom:link href="{{.FeedURL}}" rel="self" type="application/rss+xml"/>
    {{range .Items}}
    <item>
      <title>{{.Title}}</title>
      <link>{{.Link}}</link>
      <description><![CDATA[{{.Description}}]]></description>
      <guid isPermaLink="true">{{.Link}}</guid>
      <pubDate>{{.PubDate}}</pubDate>
    </item>
    {{end}}
  </channel>
</rss>`
```

### Feed Data Structure

```go
type FeedData struct {
    Title         string
    Link          string
    Description   string
    Language      string
    LastBuildDate string
    FeedURL       string
    Items         []FeedItem
}

type FeedItem struct {
    Title       string
    Link        string
    Description string
    PubDate     string
}

// RFC 822 date formatting
func formatRFC822(t time.Time) string {
    return t.Format(time.RFC1123Z)
}
```

### Generate Feed

```go
func generateRSS(data FeedData, outputPath string) error {
    tmpl, err := template.New("rss").Parse(rssTemplate)
    if err != nil {
        return err
    }

    f, err := os.Create(outputPath)
    if err != nil {
        return err
    }
    defer f.Close()

    return tmpl.Execute(f, data)
}
```

## HTML Autodiscovery

Add to your HTML template's `<head>`:

### templ Component

```go
templ Head(siteURL string) {
    <head>
        <meta charset="UTF-8"/>
        <title>My Site</title>

        // RSS autodiscovery
        <link rel="alternate" type="application/rss+xml"
              title="RSS Feed" href={ siteURL + "/feed.xml" }/>

        // Atom autodiscovery (optional)
        <link rel="alternate" type="application/atom+xml"
              title="Atom Feed" href={ siteURL + "/atom.xml" }/>

        // JSON Feed autodiscovery (optional)
        <link rel="alternate" type="application/feed+json"
              title="JSON Feed" href={ siteURL + "/feed.json" }/>
    </head>
}
```

### Plain HTML

```html
<head>
    <link rel="alternate" type="application/rss+xml"
          title="RSS Feed" href="https://example.com/feed.xml">
</head>
```

## Static Site Generator Integration

### Build Process

```go
func Build() error {
    // 1. Parse content files
    posts, err := parseMarkdownPosts("content/posts")
    if err != nil {
        return err
    }

    // 2. Sort by date (newest first)
    sort.Slice(posts, func(i, j int) bool {
        return posts[i].Date.After(posts[j].Date)
    })

    // 3. Generate HTML pages
    for _, post := range posts {
        if err := generateHTML(post); err != nil {
            return err
        }
    }

    // 4. Generate RSS feed (limit to recent posts)
    recentPosts := posts
    if len(posts) > 20 {
        recentPosts = posts[:20]
    }

    if err := generateFeed(recentPosts); err != nil {
        return err
    }

    return nil
}
```

### Post Structure

```go
type Post struct {
    Title       string
    Slug        string
    Date        time.Time
    Description string
    Content     string // HTML content
    URL         string // Absolute URL
}

func (p Post) ToFeedItem() *feeds.Item {
    return &feeds.Item{
        Title:       p.Title,
        Link:        &feeds.Link{Href: p.URL},
        Description: p.Description,
        Content:     p.Content,
        Id:          p.URL,
        Created:     p.Date,
        Updated:     p.Date,
    }
}
```

## Validation

### Programmatic Validation

```go
import "encoding/xml"

func validateXML(content []byte) error {
    var v interface{}
    return xml.Unmarshal(content, &v)
}
```

### W3C Validator Integration

```bash
# Validate local file
curl -F "rawdata=@public/feed.xml" https://validator.w3.org/feed/check.cgi

# Or use online validator
# https://validator.w3.org/feed/
```

## Common Patterns

### Conditional Feed Generation

```go
// Only generate feed if there are posts
if len(posts) > 0 {
    generateFeed(posts)
}
```

### Category/Tag Feeds

```go
// Group posts by category
categories := make(map[string][]Post)
for _, post := range posts {
    for _, cat := range post.Categories {
        categories[cat] = append(categories[cat], post)
    }
}

// Generate feed for each category
for cat, catPosts := range categories {
    generateFeed(catPosts, fmt.Sprintf("public/categories/%s/feed.xml", cat))
}
```

### Incremental Builds

```go
// Check if feed needs regeneration
feedPath := "public/feed.xml"
feedInfo, err := os.Stat(feedPath)
if err == nil {
    // Feed exists, check if any post is newer
    needsRegen := false
    for _, post := range posts {
        if post.ModifiedAt.After(feedInfo.ModTime()) {
            needsRegen = true
            break
        }
    }
    if !needsRegen {
        return nil // Skip regeneration
    }
}
```

## Serving Feeds

### Content-Type Headers

When serving feeds via HTTP:

```go
http.HandleFunc("/feed.xml", func(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/rss+xml; charset=utf-8")
    http.ServeFile(w, r, "public/feed.xml")
})

http.HandleFunc("/atom.xml", func(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/atom+xml; charset=utf-8")
    http.ServeFile(w, r, "public/atom.xml")
})

http.HandleFunc("/feed.json", func(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/feed+json; charset=utf-8")
    http.ServeFile(w, r, "public/feed.json")
})
```

### Caching Headers

```go
func serveFeed(w http.ResponseWriter, r *http.Request, path string) {
    info, _ := os.Stat(path)

    // Last-Modified header
    w.Header().Set("Last-Modified", info.ModTime().UTC().Format(http.TimeFormat))

    // ETag header
    etag := fmt.Sprintf(`"%x-%x"`, info.ModTime().Unix(), info.Size())
    w.Header().Set("ETag", etag)

    // Cache control
    w.Header().Set("Cache-Control", "public, max-age=3600")

    http.ServeFile(w, r, path)
}
```
