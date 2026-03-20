---
name: parse-figjam
description: Use when the user provides a FigJam URL or FigJam JSON file and wants to extract, analyze, or transform the diagram content
---

# Parse FigJam

Extract semantic context from FigJam board JSON node trees produced by the Figma REST API.

## Fetch Phase

Run the fetch script with the FigJam URL:

```
~/.claude/skills/parse-figjam/fetch_figjam.sh <figjam_url>
```

**Error handling:**
- Script not found → tell user: "`fetch_figjam.sh` not found at `~/.claude/skills/parse-figjam/fetch_figjam.sh`"
- Non-zero exit → show stderr, ask "Want to retry?"
- Auth failure visible in stderr → suggest checking credentials/tokens, then ask "Want to retry?"

**On success:**
- Glob for the most recently modified `*.json` in `~/.claude/skills/parse-figjam/output/`
- If no JSON found → tell user, list JSON files in that directory

---

## Parsing Rules

### Fields to extract (every node)

| Field | Purpose |
|-------|---------|
| `name` | Node label |
| `characters` | Text content (use if present; else fall back to `name`) |
| `type` | Node type (see table below) |
| `children` | Hierarchy — parent/child = containment or grouping |

### CONNECTOR-specific fields

| Field | Purpose |
|-------|---------|
| `connectorStart.endpointNodeId` | ID of source node |
| `connectorEnd.endpointNodeId` | ID of target node |
| `connectorStartStrokeCap` | `LINE_ARROW` = arrow at start |
| `connectorEndStrokeCap` | `LINE_ARROW` = arrow at end |
| `strokeDashes` | Present = dashed line (distinct relationship type) |

**Arrow direction logic:** check both caps — one arrow = directed (start→end), both arrows = bidirectional, no arrows = undirected.

### Fill color

- Read RGB from `fills[0].color`
- Group nodes by distinct fill colors
- Do not assume fixed color meanings
- If a SECTION named `legend` (case-insensitive) exists → use its contents to map colors to meanings
- No legend + significant color variation → ask user what colors mean before producing output

### Fields to ignore

`absoluteBoundingBox`, `absoluteRenderBounds`, `relativeTransform`, `size`, `blendMode`, `cornerRadius`, `cornerSmoothing`, `scrollBehavior`, `strokeWeight`, `strokeAlign`, `strokeJoin`, `fillGeometry`, `strokeGeometry`, `constraints`, `effects`, `shapeType`, `textBackground`

### Node type meanings

| Type | Meaning |
|------|---------|
| `SECTION` | Grouping container with a label |
| `SHAPE_WITH_TEXT` | Entity, field, label, or named element |
| `CONNECTOR` | Relationship between two nodes |
| `STICKY_NOTE` | Annotation or comment |
| `TEXT` | Standalone text label |
| Unknown | Include with raw type name — never skip |

### Connector resolution steps

1. Read `connectorStart.endpointNodeId` and `connectorEnd.endpointNodeId`
2. Look up each ID in the full node tree → get `name` / `characters`
3. If an ID is not found in the tree → label it `"external reference to [nodeId]"`
4. Check `strokeDashes`: present = dashed, absent = solid
5. Check both stroke caps to determine arrow direction

---

## User Interaction Flow

### Step 1 — Summary choice

After parsing, prompt the user:

> The diagram is loaded. How would you like to proceed?
> 1. Skip summary — go straight to deeper questions
> 2. See a summary of what I found, then continue

### Step 2 — Summary (if chosen)

Provide:
- One-sentence overview: diagram type and scope
- Structured breakdown:
  - Sections and their contents
  - Nodes grouped by fill color
  - Relationships listed as `source → target` with line style (solid/dashed) and direction
  - Annotations (sticky notes, standalone text)

### Step 3 — Output menu (single-select)

> What would you like to produce from this diagram?
> 1. Markdown documentation
> 2. Jira tickets / task breakdown
> 3. Database schema / migrations
> 4. Code models / types
> 5. Mermaid diagram
> 6. Something else — tell me what you need

### Step 4 — Follow-up questions

| Choice | Ask |
|--------|-----|
| Markdown documentation | What level of detail? Any specific doc structure? |
| Jira tickets / task breakdown | What project? Epic or individual stories? Any template? |
| Database schema / migrations | What database? Any ORM preference? |
| Code models / types | What language? Classes, interfaces, or types? |
| Mermaid diagram | What diagram type — ERD, flowchart, sequence? |
| Something else | Open-ended: what do you need? |

### Step 5 — Produce output

Generate the requested output based on parsed diagram data and user answers. If the diagram data is insufficient for the chosen output type, tell the user what is missing and ask how to proceed.

### Step 6 — Loop

Ask: "Would you like another output from this diagram?"
- Yes → return to Step 3 (output menu)
- No → done

---

## Edge Cases

| Situation | Handling |
|-----------|---------|
| Node with no `characters` | Use `"(unnamed)"` |
| Empty section | Note it as empty — don't omit it |
| Connector endpoint ID not in tree | `"external reference to [nodeId]"` |
| Unknown node type | Include it with raw type name, never skip |
| Full JSON tree | Never reproduce it in output |
