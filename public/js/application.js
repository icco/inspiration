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

  // http://api.jquery.com/jQuery.when/
  var requests = [];

  $('.embed').each(function(index, embed_div) {
    var url = $(embed_div).data('embed');

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
          build_element(image_link, url, title, $(embed_div));
        }
      });
    } else if (deviant_re.test(url)) {
      var oembed_url = 'http://backend.deviantart.com/oembed?url=' + encodeURIComponent(url) + '&format=jsonp&callback=?';
      request = $.getJSON(oembed_url, function(data) {
        images = data;
      }).done(function() {
        var title = '"' + images.title + '" by ' + images.author_name;

        if (images.thumbnail_url != undefined && images.title != undefined) {
          element = build_element(images.thumbnail_url, url, title, $(embed_div));
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
          element = build_element(image_url, url, title, $(embed_div));
        }
      });
    } else {
      console.log("Unkown: " + url);
    }

    requests.push(request);
  });

  $.when.apply($, requests).done(function() {
    $("img").unveil(200, function() {
      $(this).load(function() {
        $('#container').isotope('reLayout')
      });
    });

    $('div.uncached img').imagesLoaded(function() {
      data = [];
      $(this).each(function() {
        img = $(this).attr('src');
        src = $(this).parents('div').data('embed');
        if (src != undefined && img != undefined) {
          data.push([img, src]);
        }
      });
      $.post('/cache', { 'pairs': data });
    });
  });
});

function build_element(image, link, title, div) {
  var a = $('<a>');
  var img = $('<img>');
  a.attr('href', link);
  a.attr('title', title);
  img.attr('data-src', image);
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
