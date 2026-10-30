Kompass "Learn KampfScript" tutorial videos
===========================================
Drop the two tutorial videos here (exact file names, lowercase):

  lesson1.mp4   Intro to KampfScript: variables, print, if, loops
  lesson2.mp4   Functions, lists/maps, and scripting the Kompass browser

Format: MP4 container, H.264 (AVC) video + AAC audio, 1920x1080 suggested
(1280x720 also fine), 30 fps, yuv420p, "faststart" (moov atom at the front).
ffmpeg example:
  ffmpeg -i in.mov -c:v libx264 -pix_fmt yuv420p -preset slow -crf 20 \
         -c:a aac -b:a 160k -movflags +faststart lesson1.mp4

Kompass also looks in %APPDATA%\Kompass\kompass\videos\ and in a "videos"
folder next to Kompass-<version>-portable.exe, and kompass://settings lets
you set a URL (https://...mp4) for each video instead.
