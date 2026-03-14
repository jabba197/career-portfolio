---
title: "Working With People"
description: "The journey from building alone to building for others"
---

## Overview

The [[index|technical journey]] tells the story of building the platform. This page tells the other story — learning how to make it useful to people who aren't me.

This was its own journey, and I got things wrong along the way.

---

## Phase 1: Built For Myself

When I first built the MDS, I built it for myself. The problems I was solving were my own: slow queries, crashing laptops, manual rebuilds. The stack worked brilliantly — for me.

But nobody else used it. Why would they? It lived on my machine, in my repo, with my assumptions baked in. I hadn't thought about what anyone else needed because I was too deep in the engineering.

This is a trap that's easy to fall into when you're building from scratch in an organisation that doesn't have an analytics engineering function. There's no team to review your work, no stakeholder requirements document, no product manager asking "who is this for?" You're just solving your own pain — and that feels like progress.

It was progress. But it wasn't enough.

---

## Phase 2: The First Convert

The shift started when a peer analyst on the UK team got curious about what I was building. Instead of showing him a demo, I asked if he wanted to build something with it.

I walked him through Git (moving from "save a copy" to branching and pull requests), dbt model structure, and the Python patterns I'd been using for data extraction. Not a training course — just pairing on real work.

He went on to build a customer dashboard for UK market leadership and a product classification report, both using the MDS as his foundation. Independently. Without me looking over his shoulder.

That was the moment it clicked: **the test of whether infrastructure works isn't whether it runs — it's whether someone else can build on it.**

---

## Phase 3: Designing For Others

Technical people often assume the work speaks for itself. It doesn't.

Early on, I made the mistake of trying to pitch the MDS — explaining the architecture, the tools, the efficiency gains. People were polite. Nobody changed how they worked. What actually worked was showing, not pitching — live dashboards, automated pipelines, real data. People could see the value without being sold on it.

Once I understood the platform needed to serve others, I started making different decisions. The commercial team needed data by 7:30 AM — that single constraint reshaped how I thought about orchestration. A colleague had customer deduplication logic living in a text file and her memory — I formalised it into a version-controlled dbt model so anyone could find, understand, and maintain it. When leadership needed a new customer report, the MDS meant another analyst could build the front-end in days instead of weeks.

None of these were in any technical spec. They came from listening to how people actually worked.

---

## The Lesson

The shift from "I built something" to "I built something others can own" is the most important thing I learned at QVC.
