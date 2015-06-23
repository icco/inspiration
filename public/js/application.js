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

  var per_req = 9;
  var total_wanted = 400;
  for (var i = 0; i < total_wanted / per_req; i++) {
    $.get("/sample.json?count=" + per_req, parse_cache_response).fail(function() {
      console.error("Error getting data.");
    });
  }
});

function parse_cache_response(data) {
  for (i in (data)) {
    build_element(data[i]["image"], data[i]["url"], data[i]["title"]);
  }
}

function build_element(image, link, title) {
  var a = $('<a>');
  var img = $('<img>');
  var div = $('<div>');

  a.attr('href', link);
  a.attr('title', title);

  img.attr('src', image);
  img.attr('alt', title);

  a.append(img);
  div.append(a);

  div.addClass('item');

  // Preload
  $(img).one('load', function() {
    $(div).addClass('item');
    $('#container').isotope('insert', $(div));
  }).each(function() {
    if(this.complete) $(this).load();
  });
}
