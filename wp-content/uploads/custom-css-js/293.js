<!-- start Simple Custom CSS and JS -->
<script type="text/javascript">
window.addEventListener('load', function () {
  const video = document.querySelector('.elementor-background-video-hosted');

  if (!video) return;

  video.loop = false;

  // Force it visible (Elementor sometimes hides it)
  video.style.display = 'block';

  video.addEventListener('timeupdate', function () {
    if (video.duration && video.currentTime >= video.duration - 0.05) {
      video.pause();
      video.currentTime = video.duration;
    }
  });
});</script>
<!-- end Simple Custom CSS and JS -->
