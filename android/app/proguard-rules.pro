# Release-build (R8) rules for BahinKo.
#
# google_mlkit_text_recognition refers to optional language packs
# (Chinese, Devanagari, Japanese, Korean) that BahinKo doesn't include:
# receipts here use Latin script. Tell R8 their absence is expected.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
