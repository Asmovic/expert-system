# Managing the bibliography in EndNote

The project framework requires the bibliography to be managed in EndNote. The
report is typeset from `report/references.bib` (biblatex + biber), so the
EndNote library is the managed copy and the `.bib` file is what LaTeX reads.
The two are linked by the citation key, stored in EndNote's **Label** field.

## 1. Generate the import file

```
python tests/bib_to_ris.py
```

This writes `report/references.ris`, which has 77 records. Each record's
BibTeX key is in the `LB` tag, and EndNote imports that tag as **Label**.
LaTeX accents are converted to Unicode (for example, H{\"o}lzle becomes
Hölzle). Rerun the script whenever `references.bib` changes.

## 2. Import into EndNote

1. Create a library: **File > New**, saved as `dc-expert-system.enl`.
2. Choose **File > Import > File...**
   - Import File: `report/references.ris`
   - Import Option: **Reference Manager (RIS)**
   - Duplicates: Import All
   - Text Translation: **Unicode (UTF-8)**
3. Check the result:
   - The library shows **77 references**.
   - Open Hölzle (2007) and Azevedo: the accents should display correctly.
   - The Label field should hold the key, for example `barroso2007`.
   - Buchanan & Shortliffe (1984) should be an *Edited Book*.
   - The five standards should import as *Standard*.
4. To see the keys at a glance, add Label as a library column:
   **Edit > Preferences > Display Fields** (on Mac: **EndNote > Settings**).

## 3. Keep the two in step

**EndNote → LaTeX.** If you change a reference in EndNote, export it as
BibTeX with the key taken from Label:

1. **Edit > Output Styles > Open Style Manager**, select **BibTeX Export**,
   then click **Edit**.
2. Under **Bibliography > Templates**, each reference type's line begins
   with the field that becomes the key, usually `Record Number`. Replace that
   field with `Label` in every template you use, then save the style under a
   new name, for example *BibTeX Export (Label key)*.
3. Select the references and choose **File > Export**, with the
   *BibTeX Export (Label key)* style and the **Text File** format.
4. Check the exported records against `references.bib`, then merge in only
   the changed entries.

EndNote does not write biblatex-specific fields such as `urldate`,
`eprinttype` and `@online`, and it drops the braces that protect
capitalisation ("{ASHRAE}", "12 {V}"). For that reason, keep
`references.bib` as the copy LaTeX reads, and do not overwrite it with a
raw EndNote export.

**LaTeX → EndNote.** If you add an entry to `references.bib`, rerun step 1
and import only the new record. Alternatively, enter it in EndNote by hand
with the same Label.

## 4. What to submit

- `dc-expert-system.enl` and its `.Data` folder, compressed together. You can
  also use **File > Compressed Library (.enlx)**, which produces one file.
- `report/references.bib` and `report/references.ris`.
