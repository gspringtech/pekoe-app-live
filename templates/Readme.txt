
When a file is uploaded to the Templates collection, a trigger fires.
The trigger will create a subcollection in /templates-meta on the same path and using the document's name.
e.g. /templates-meta/Readme_txt/

This collection contains contents.xml and links.xml.
The links are the hyperlinks from the tempate (those that start with http://pekoe.io)

MS Word
A word document is run through a pre-processing stylesheet ("replace-word-hyperlinks.xsl")
which fixes up multiple runs within an hyperlink (for example in a date which might have 3 or more runs
- one of which will have a subscript on the ordinal indicator - "st" or "nd" or "rd" etc)

I think that's all it should do.