$(document).ready(function() {
  var width = $('#container').width();
  var columns = 1;

  if (width > 400) {
    columns = Math.floor(width / 342);
  }

  var column_width = (width / columns) - 12;

  $('#container').isotope({
    animationEngine : 'css',
    itemSelector : '.item',
    masonry: {},
  });

  // http://stackoverflow.com/questions/7270947/rails-3-1-csrf-ignored
  $.ajaxSetup({
    beforeSend: function(xhr) { xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content')); }
  });

  $('.item').css('width', column_width);

  get_more(150, column_width);

  var intervalID = window.setInterval(update_count, 5000);
});

window.onscroll = function(ev) {
  if ((window.innerHeight + window.scrollY) >= document.body.offsetHeight) {
    // you're at the bottom of the page
    console.log("Bottom of the page, request 20 more.");
    get_more(20);
  }
};

function update_count() {
  // Update about box.
  $('#imgcount').text($('img').size());
}

function get_more(wanted, column_width) {
  var per_req = 20;
  var parse_cache_response = width_function_builder(column_width);
  for (var i = 0; i < wanted / per_req; i++) {
    $.get("/sample.json?count=" + per_req, parse_cache_response).fail(function() {
      console.error("Error getting data.");
    });
  }
}

function width_function_builder(column_width) {
  return function(data) {
    for (i in (data)) {
      build_element(data[i]["image"], data[i]["url"], data[i]["title"], column_width);
    }
  }
}

function build_element(image, link, title, column_width) {
  var a = $('<a>');
  var img = $('<img>');
  var div = $('<div>');

  a.attr('href', link);
  a.attr('title', title);

  img.attr('src', image);
  img.attr('alt', title);
  img.css('width', column_width);

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
