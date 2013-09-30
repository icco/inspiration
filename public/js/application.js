$(document).foundation();
$('#container').imagesLoaded(function(){
  $('#container').isotope({ itemSelector : '.item', animationEngine : 'css' });
});

// http://stackoverflow.com/questions/7270947/rails-3-1-csrf-ignored
$.ajaxSetup({
  beforeSend: function(xhr) {
                xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'));
              }
});

// http://api.jquery.com/jQuery.when/
var requests = [];

$('.embed').each(function(index, value) {
  var url = $(value).data('embed');

  var dribbble_re = /http\:\/\/dribbble\.com\/shots\//;
  var deviant_re = /deviantart\.com/;
  var flickr_re = /www\.flickr\.com/;
  var request;

  if (dribbble_re.test(url)) {
    var oembed_url = 'http://api.dribbble.com/shots/' + url.replace(dribbble_re, "") + '?callback=?';
    request = $.getJSON(oembed_url, function(data) {
      images = data;
    }).done(function() {
      var title = '"' + images.title + '" by ' + images.player.name;
      var image_link = "";

      if (images.image_400_url != undefined) {
        image_link = images.image_400_url;
      } else {
        image_link = images.image_teaser_url;
      }

      if (images.image_teaser_url != undefined) {
        element = build_element(image_link, url, title);
        $(value).append(element);
      }
    });
  } else if (deviant_re.test(url)) {
    var oembed_url = 'http://backend.deviantart.com/oembed?url=' + encodeURIComponent(url) + '&format=jsonp&callback=?';
    request = $.getJSON(oembed_url, function(data) {
      images = data;
    }).done(function() {
      var title = '"' + images.title + '" by ' + images.author_name;

      if (images.thumbnail_url != undefined && images.title != undefined) {
        element = build_element(images.thumbnail_url, url, title);
        $(value).append(element);
      }
    });
  } else if (flickr_re.test(url)) {
    var oembed_url = 'http://www.flickr.com/services/oembed?url=' + encodeURIComponent(url) + '&format=json&&maxwidth=300&jsoncallback=?';
    request = $.getJSON(oembed_url, function(data) {
      images = data;
    }).done(function() {
      var title = '"' + images.title + '" by ' + images.author_name;
      var image_url = "";
      if (images.thumbnail_url != undefined) {
        image_url = images.thumbnail_url.replace(/\_s\./, "_n.");
      }

      if (images.thumbnail_url != undefined && images.title != undefined) {
        element = build_element(image_url, url, title);
        $(value).append(element);
      }
    });
  } else {
    console.log("Unkown: " + url);
  }

  requests.push(request);
});

$('#container').imagesLoaded(function() {
  $('.embed').each(function(i, value) {
    $(value).imagesLoaded(function() {
      $(value).removeClass('embed');
      $(value).addClass('item');
      $('#container').isotope('insert', $(value));
    });
  });
});

function cache(source, img) {
  $.when(requests).done(function(){
    $.post('/cache', { 'favorite': source, 'image': img });
  });
}

function build_element(image, link, title) {
  // Preload
  new Image().src = image;

  var a = $('<a>');
  var img = $('<img>');
  a.attr('href', link);
  a.attr('title', title);
  img.attr('src', image);
  img.attr('alt', title);
  a.append(img);
  // cache(link, image);

  return $(a);
}
