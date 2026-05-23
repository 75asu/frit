# Content and Marketing Strategy (May 2026)

## What Already Works

Two weeks of consistent LinkedIn/Twitter posts. Posts follow a clear pattern: technical primitive, one result, both product URLs. This is the right foundation. The question is how to extend it into something that compounds over months, not just weeks.

---

## Blog Platform: Where to Post Technical Articles

**The honest mechanics of technical blog SEO:**

Short-term (0-3 months): almost nothing. Google does not trust new domains or new writers quickly. The exception is dev.to and Hashnode because they are high-authority domains - articles there can rank for niche searches within 4-6 weeks.

Medium-term (3-12 months): one or two well-targeted long articles on a high-authority platform can start pulling 100-500 organic visits per month if they hit a niche keyword with low competition. "vLLM DCGM integration Go" or "token path SLO design example" - nobody is writing those and any infra hiring manager who Googles those terms is exactly the audience we want.

Long-term (12+ months): a personal blog with consistent publishing can build domain authority and rank for broader terms. But this requires consistent publishing for a year before it compounds. The return is real but the timeline is long.

**Recommendation for now: dev.to as primary, cross-post to personal blog.**

Why dev.to:
- High domain authority. Articles can rank within weeks, not months.
- SRE/DevOps/Platform engineering community already there.
- Free. Zero setup friction.
- GitHub-integrated. Write in Markdown locally, publish via API or paste.
- Articles show up in GitHub searches via tags like `#kubernetes`, `#prometheus`, `#gpu`.

Why not Medium:
- Paywalled articles don't rank (Google deindexes them after the soft paywall).
- Free articles do rank, but the audience is more general tech, less infra hiring managers.

Why not personal blog only (yet):
- A new domain with zero backlinks will not rank for 6-9 months minimum. The time investment before any return is too high right now.
- Keep the personal blog as a landing page (75asu.pages.dev already exists), but publish the actual articles on dev.to where they will rank faster.

**Future state (12 months):** republish dev.to articles on personal blog via canonical URL pointing to dev.to (tells Google the original is dev.to, avoids duplicate penalty). When the personal blog eventually builds authority, switch the canonical direction.

---

## Content Rotation: Four Projects, One Writing Schedule

The projects: truss, kiln, platform-zero, Frit.

Each project generates a different type of content. The rotation maps project work to content output without requiring extra writing - write the article at the same time as doing the work.

| Project | Article type | Cadence |
|---|---|---|
| platform-zero | Architecture decisions - "why I chose Terragrunt over raw Terraform," module boundary design | One per 2-3 modules shipped |
| Frit | Technical walkthrough - "DCGM on a T4: what works, what breaks, what I measured" | One per major experiment |
| Frit | Design docs - "Designing SLOs for inference workloads without a production cluster" | One per milestone |
| kiln | Engineering diary - namespace isolation internals, what Go taught about Linux | One per phase completion |
| truss | Ops in public - real incident postmortems, what broke, how we fixed it | One per incident or interesting config decision |

This is roughly one article per 2-3 weeks without any extra work - just writing up what is already being built.

---

## How Articles Connect to Social Posts

The existing social post pattern is short-form: what got built, primitive used, metric, both URLs.

The article is the long-form version of the same post. The workflow:

1. Ship something (Frit session, platform-zero module, kiln phase)
2. Write the Twitter/LinkedIn post (already doing this, 2 weeks in)
3. Expand the same content into a 600-900 word article for dev.to within 48 hours
4. Link back to the article from the next social post: "wrote this up in full at dev.to/75asu/..."

The social post sends traffic to the article. The article ranks on Google over time and sends new readers back to the Twitter/LinkedIn profiles. This is the compounding loop.

---

## What an Article Should Look Like

The same rules as the social posts apply: lowercase, no hype, specific numbers, concrete results. The article just has more depth.

Structure for a technical walkthrough (Frit type):

```
Title: [What I built and what I measured] — lowercase, descriptive, no clickbait
Intro: The problem I was trying to solve. One paragraph.
Setup: The actual configuration. Show the code or command.
What happened: The specific result with numbers.
What broke: Honest about failure. This builds trust.
What I'd do differently: One sentence.
What's next: Points to the next article or the GitHub repo.
```

This is readable in 5 minutes, has code (Google indexes code blocks well), and is honest (which keeps readers coming back).

---

## Network Building: How This Converts to Opportunities

The mechanism is not "go viral." The mechanism is:

1. Write about a niche topic that hiring managers and senior engineers actually Google ("DCGM on Lightning.ai T4," "SLO design for vLLM serving," "Terragrunt remote state layout for multi-env AWS")
2. The right people find the article when they search for it - not from the post, from Google
3. They follow the profile. They remember the name. When they have a role that matches, the name is not cold.
4. The article lives permanently. A social post is gone in 24 hours. An article from 6 months ago still sends a reader every week.

The ROI is not immediate. But a body of 20-30 well-targeted technical articles over 12 months is a searchable portfolio that does recruiting work without active effort. It is also a legitimate substitute for the "conference talks" signal that most Staff-level candidates have - writing in public is the indie engineer's version of that.

---

## Starting Point: First Three Articles

These are the highest-signal first three articles based on current project state:

**Article 1 (next Frit session):**
"Running DCGM on a Lightning.ai T4: what the docs don't tell you"
- Niche enough to rank. Hiring managers at Lightning, Anthropic, Together AI all care about DCGM.
- Write it after the DCGM install session. Takes 45 minutes.

**Article 2 (after platform-zero module 20+):**
"Terragrunt module layout for 24-module AWS simulation: the decisions I changed"
- Targets the Together AI Amsterdam hiring profile exactly.
- Write it after the platform-zero `make tf-all` is clean across all environments.

**Article 3 (after first Frit SLO design):**
"SLO design for inference workloads when you don't have a production cluster"
- Unique angle. Nobody writes about designing AI SLOs at homelab scale.
- Directly signals Anthropic AIRE readiness to anyone who finds it.

Publish all three on dev.to under the handle 75asu. Link from bio to 75asu.pages.dev, kiln.binarysquad.org, truss.binarysquad.org.

---

## Summary: What to Do This Week

1. Finish DCGM install on T4 (next Frit session already planned)
2. While doing it, take notes. Write Article 1 immediately after.
3. Publish to dev.to. Link from the next social post.
4. Continue existing social post cadence - no change there, it is already working.
5. One article per 2-3 weeks from here. No more, no less.

The social posts prove you ship. The articles prove you understand. The projects are the receipts. Together they build the profile that makes an inbound message from a Together AI or Google recruiter not a cold start.
