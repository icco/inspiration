$(document).ready(function() {
  $('#container').isotope({
    animationEngine : 'css',
    itemSelector : '.item',
    masonry: { },
  });

  // http://stackoverflow.com/questions/7270947/rails-3-1-csrf-ignored
  $.ajaxSetup({
    beforeSend: function(xhr) { xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content')); }
  });

  $.get("/cache.json", function(data) {
    console.log(data);
  });
});

function build_element(image, link, title, div) {
  var a = $('<a>');
  var img = $('<img>');
  a.attr('href', link);
  a.attr('title', title);
  img.attr('src', image);
  img.attr('alt', title);
  a.append(img);
  $(div).append(a);

  // Preload
  $(img).one('load', function() {
    $(div).addClass('item');
    $(div).removeClass('embed');
    $('#container').isotope('insert', $(div));
  }).each(function() {
    if(this.complete) $(this).load();
  });
}
