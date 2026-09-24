#!/usr/bin/env python3
"""Prints what the LFS book tells the reader to type, section by section.

  book-commands.py BOOK.html [chapter-number ...]

The one-page book marks every command as <pre class="userinput"> and every
section with a heading whose anchor begins with ch-; nothing more is needed to
turn the book into something a script can be written from and checked against.
"""
import html, re, sys

book = open(sys.argv[1], encoding="utf-8").read()
wanted = set(sys.argv[2:])
pieces = re.split(r'(<h[12][^>]*class="(?:title|sect1)"[^>]*>.*?</h[12]>)', book, flags=re.S)
title = ""
for piece in pieces:
    if piece.startswith("<h"):
        title = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", piece))).strip()
        continue
    number = title.split(".")[0].strip()
    if wanted and number not in wanted:
        continue
    commands = re.findall(r'<pre class="userinput">(.*?)</pre>', piece, flags=re.S)
    if commands:
        print(f"\n######## {title}")
        for c in commands:
            print(html.unescape(re.sub(r"<[^>]+>", "", c)).rstrip())
            print("--")
