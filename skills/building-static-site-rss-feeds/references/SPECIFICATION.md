# Feed Format Specifications

Detailed specifications for RSS 2.0, Atom 1.0, and JSON Feed formats.

## RSS 2.0 Specification

RSS 2.0 is the most widely supported feed format. The specification is frozen and maintained by the RSS Advisory Board.

### Document Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <!-- Channel elements -->
    <item>
      <!-- Item elements -->
    </item>
  </channel>
</rss>
```

### Required Channel Elements

| Element | Description |
|---------|-------------|
| `<title>` | Name of the feed |
| `<link>` | URL of the website |
| `<description>` | Summary of the feed content |

### Optional Channel Elements

| Element | Description | Example |
|---------|-------------|---------|
| `<language>` | ISO 639 language code | `en-us` |
| `<copyright>` | Copyright notice | `Copyright 2026 Example` |
| `<pubDate>` | Publication date (RFC 822) | `Sat, 01 Feb 2026 12:00:00 GMT` |
| `<lastBuildDate>` | Last modification date | `Sat, 01 Feb 2026 12:00:00 GMT` |
| `<category>` | Feed category | `Technology` |
| `<generator>` | Program that generated feed | `My Static Site Generator` |
| `<ttl>` | Minutes feed can be cached | `60` |
| `<image>` | Feed logo/image | See below |
| `<atom:link rel="self">` | Self-reference (recommended) | See below |

### Item Elements

An item must contain either `<title>` or `<description>`.

| Element | Required | Description |
|---------|----------|-------------|
| `<title>` | title OR description | Article title |
| `<link>` | No | Article URL |
| `<description>` | title OR description | Article content/summary |
| `<author>` | No | Email of author |
| `<category>` | No | Article category |
| `<guid>` | No (recommended) | Unique identifier |
| `<pubDate>` | No | Publication date |
| `<enclosure>` | No | Media attachment |

### GUID Element

```xml
<!-- Permalink GUID (default) -->
<guid>https://example.com/article-slug</guid>

<!-- Non-permalink GUID -->
<guid isPermaLink="false">urn:uuid:1225c695-cfb8-4ebb-aaaa-80da344efa6a</guid>
```

### Date Format (RFC 822)

Format: `Day, DD Mon YYYY HH:MM:SS TZ`

Examples:
- `Sat, 01 Feb 2026 12:00:00 GMT`
- `Sat, 01 Feb 2026 12:00:00 +0000`

---

## Atom 1.0 Specification

Atom is defined in RFC 4287 and provides better internationalization and stricter validation.

### Document Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <id>urn:uuid:feed-id</id>
  <title>Feed Title</title>
  <updated>2026-02-01T12:00:00Z</updated>
  <entry>
    <!-- Entry elements -->
  </entry>
</feed>
```

### Required Feed Elements

| Element | Description |
|---------|-------------|
| `<id>` | Unique feed identifier (IRI) |
| `<title>` | Feed title |
| `<updated>` | Last modification (RFC 3339) |

### Entry Elements

| Element | Required | Description |
|---------|----------|-------------|
| `<id>` | Yes | Unique entry identifier |
| `<title>` | Yes | Entry title |
| `<updated>` | Yes | Last modification |
| `<content>` | Recommended | Full content |
| `<link>` | Recommended | Entry URL |
| `<summary>` | Recommended | Entry summary |
| `<published>` | No | Original publication date |

### Date Format (RFC 3339)

Format: `YYYY-MM-DDTHH:MM:SSZ`

Examples:
- `2026-02-01T12:00:00Z`
- `2026-02-01T07:00:00-05:00`

---

## JSON Feed 1.1 Specification

JSON Feed provides a simpler alternative using JSON instead of XML.

### Document Structure

```json
{
  "version": "https://jsonfeed.org/version/1.1",
  "title": "Site Title",
  "home_page_url": "https://example.com",
  "feed_url": "https://example.com/feed.json",
  "items": [
    {
      "id": "unique-id",
      "url": "https://example.com/article",
      "title": "Article Title",
      "content_html": "<p>Article content</p>",
      "date_published": "2026-02-01T12:00:00Z"
    }
  ]
}
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Must be `https://jsonfeed.org/version/1.1` |
| `title` | string | Feed title |
| `items` | array | Array of item objects |

### Item Fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique identifier |
| `content_html` or `content_text` | One required | Content |
| `url` | No | Item URL |
| `title` | No | Item title |
| `date_published` | No | RFC 3339 date |

---

## Format Comparison

| Feature | RSS 2.0 | Atom 1.0 | JSON Feed |
|---------|---------|----------|-----------|
| Date format | RFC 822 | RFC 3339 | RFC 3339 |
| Content type | Implicit | Explicit | Explicit |
| Unique ID | Optional | Required | Required |
| Podcast support | Best | Good | Good |
| Parser complexity | Medium | Medium | Low |

---

## References

- [RSS 2.0 Specification](https://www.rssboard.org/rss-specification)
- [Atom RFC 4287](https://www.rfc-editor.org/rfc/rfc4287)
- [JSON Feed 1.1](https://www.jsonfeed.org/version/1.1/)
