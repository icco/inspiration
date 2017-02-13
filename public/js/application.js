$(document).ready(function() {
  var width = $('#container').width();
  var columns = 1.0;

  if (width > 400) {
    columns = 2.0;
  }

  if (width > 700) {
    columns = 3.0;
  }

  if (width > 1000) {
    columns = 4.0;
  }

  // TODO: write simple formula so this scales forever
  if (width > 1900) {
    columns = 6.0;
  }

  // 5px padding, 1px margin on each image, 1px border
  var column_width = (width - (columns * 14)) / columns;

  console.log(width, columns, column_width)

  $('#container').isotope({
    animationEngine : 'css',
    itemSelector : '.item',
    masonry: {
      columnWidth: column_width + 14
    },
  });

  $('.item p').css('width', column_width);

  page = 1;
  get_more(page, column_width);
  max_pages = 100;

  $.get("/stats.json", function(data) {
    console.log(data);
    $('#total').text(data["images"]);
    max_pages = data["pages"];
  }).fail(function() {
    console.error("Error getting stats.");
  });

  window.onscroll = function(ev) {
    if ((window.innerHeight + window.scrollY) >= document.body.offsetHeight) {
      // you're at the bottom of the page
      console.log("Bottom of the page, requesting next page.");
      page += 1;
      console.log(page, max_pages);
      if (page <= max_pages) {
        get_more(page, column_width);
      }
    }
  };

  var intervalID = window.setInterval(update_count, 5000);
});

function update_count() {
  // Update about box.
  $('#imgcount').text($('img').length);
}

function get_more(page, column_width) {
  var parse_cache_response = width_function_builder(column_width);
  $.get("/data/" + page + ".json", parse_cache_response).fail(function() {
    console.error("Error getting data.");
  });
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
