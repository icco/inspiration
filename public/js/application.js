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

  get_more(150);
});

window.onscroll = function(ev) {
  if ((window.innerHeight + window.scrollY) >= document.body.offsetHeight) {
    // you're at the bottom of the page
    console.log("Bottom of the page, request 20 more.");
    get_more(20);
  }
};

function get_more(wanted) {
  var per_req = 10;
  for (var i = 0; i < wanted / per_req; i++) {
    $.get("/sample.json?count=" + per_req, parse_cache_response).fail(function() {
      console.error("Error getting data.");
    });
  }
}

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
