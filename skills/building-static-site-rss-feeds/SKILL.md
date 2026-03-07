---
name: building-static-site-rss-feeds
description: Creates static websites with RSS/Atom/JSON Feed support for content syndication. Use when building static sites with feeds, implementing RSS in Hugo/Jekyll/custom generators, adding feed autodiscovery, or when user mentions RSS, Atom, feeds, or content syndication.
---

# Building Static Sites with RSS Feeds

Create static websites that support RSS/Atom feeds for content syndication, allowing readers to subscribe via feed readers.

**Use this skill when** implementing RSS feeds in static sites, choosing feed formats, setting up autodiscovery, or generating feeds from content.

**Supporting files:** [SPECIFICATION.md](references/SPECIFICATION.md) for feed format details, [IMPLEMENTATION.md](references/IMPLEMENTATION.md) for code examples.

## Quick Start

Add feed support to a static site:

1. **Choose format**: RSS 2.0 (most compatible) or Atom 1.0 (more features)
2. **Generate feed XML**: From content metadata (title, date, description)
3. **Add autodiscovery**: Link tag in HTML head
4. **Validate**: Use W3C Feed Validator

## Feed Format Selection

| Format | Best For | Notes |
|--------|----------|-------|
| RSS 2.0 | Maximum compatibility, podcasts | Frozen spec, simpler |
| Atom 1.0 | International content, strict validation | RFC 4287, better date handling |
| JSON Feed | Modern APIs, developer preference | Simpler parsing, less support |

**Recommendation**: Use RSS 2.0 for broad compatibility. Add Atom if you need internationalization.

## Minimal RSS 2.0 Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Site Title</title>
    <link>https://example.com</link>
    <description>Site description</description>
    <lastBuildDate>Sat, 01 Feb 2026 12:00:00 +0000</lastBuildDate>

    <item>
      <title>Article Title</title>
      <link>https://example.com/article</link>
      <description>Article summary or full content</description>
      <guid isPermaLink="true">https://example.com/article</guid>
      <pubDate>Fri, 31 Jan 2026 10:00:00 +0000</pubDate>
    </item>
  </channel>
</rss>
```

## HTML Autodiscovery

Add to `<head>` of every page:

```html
<link rel="alternate" type="application/rss+xml"
      title="RSS Feed" href="https://example.com/feed.xml">
```

For Atom:
```html
<link rel="alternate" type="application/atom+xml"
      title="Atom Feed" href="https://example.com/atom.xml">
```

## Go Implementation

Using `gorilla/feeds` library:

```go
import "github.com/gorilla/feeds"

feed := &feeds.Feed{
    Title:       "Site Title",
    Link:        &feeds.Link{Href: "https://example.com"},
    Description: "Site description",
    Updated:     time.Now(),
}

feed.Items = []*feeds.Item{
    {
        Title:       "Article Title",
        Link:        &feeds.Link{Href: "https://example.com/article"},
        Description: "Article content",
        Id:          "https://example.com/article",
        Created:     time.Now(),
    },
}

rss, _ := feed.ToRss()    // RSS 2.0
atom, _ := feed.ToAtom()  // Atom 1.0
json, _ := feed.ToJSON()  // JSON Feed
```

## Best Practices

### Content
- **Full content**: Include complete articles, not just excerpts
- **Absolute URLs**: All links must be absolute (`https://...`)
- **Unique GUIDs**: Use permalink URLs as identifiers

### Performance
- **Keep under 150KB**: Some readers have size limits
- **Limit items**: 10-20 recent items is typical
- **Support caching**: Return `ETag` and `Last-Modified` headers

### Dates
- **RSS 2.0**: RFC 822 format (`Sat, 01 Feb 2026 12:00:00 +0000`)
- **Atom**: RFC 3339 format (`2026-02-01T12:00:00Z`)

## Hugo Integration

Hugo generates RSS automatically at `/index.xml`. Customize:

```
layouts/_default/rss.xml
```

Add autodiscovery in `layouts/partials/head.html`:
```html
{{ with .OutputFormats.Get "RSS" }}
<link rel="alternate" type="{{ .MediaType }}" href="{{ .Permalink }}" title="{{ $.Site.Title }}">
{{ end }}
```

## Validation

Always validate feeds before deployment:
- **W3C Validator**: https://validator.w3.org/feed/
- **Feed Validator**: https://www.feedvalidator.org/

Common errors:
- Relative URLs (must be absolute)
- Invalid date formats
- Missing required elements
- Encoding issues with special characters

## Checklist

- [ ] Feed generates valid XML/JSON
- [ ] All URLs are absolute
- [ ] Dates use correct format (RFC 822 for RSS, RFC 3339 for Atom)
- [ ] GUIDs are unique and stable
- [ ] Autodiscovery link in HTML head
- [ ] Feed validates with W3C validator
- [ ] Content encoding is UTF-8

## Resources

- [RSS 2.0 Specification](https://www.rssboard.org/rss-specification)
- [Atom 1.0 RFC 4287](https://validator.w3.org/feed/docs/rfc4287.html)
- [JSON Feed Spec](https://www.jsonfeed.org/)
- [RSS Best Practices](https://www.rssboard.org/rss-profile)
