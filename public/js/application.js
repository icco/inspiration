$(document).foundation();
$('#container').isotope({ itemSelector : '.item' });
$('#container').isotope('shuffle');

// http://api.jquery.com/jQuery.when/
var requests = [];

$('.embed').each(function(index, value) {
  var url = $(value).data('embed');

  var dribbble_re = /http\:\/\/dribbble\.com\/shots\//;
  var deviant_re = /deviantart\.com/
  var flickr_re = /www\.flickr\.com/
  var request;

  if (dribbble_re.test(url)) {
    var oembed_url = 'http://api.dribbble.com/shots/' + url.replace(dribbble_re, "") + '?callback=?';
    request = $.getJSON(oembed_url, function(data) {
      images = data;
    }).complete(function() {
      var a = $('<a>');
      var img = $('<img class="dribbble">');
      var div = $('<div class="item uncached">');

      var title = '"' + images.title + '" by ' + images.player.name;

      if (images.image_400_url != undefined) {
        img.attr('src', images.image_400_url);
      } else {
        img.attr('src', images.image_teaser_url);
      }
      img.attr('alt', title);

      a.attr('href', url);
      a.attr('title', title);

      if (images.image_teaser_url != undefined) {
        a.append(img);
        div.append(a);
        $('#container').imagesLoaded(function(){ $('#container').isotope('insert', div); });
      } else {
        // Not a valid dribbble
        // console.log(images);
      }
    });
  } else if (deviant_re.test(url)) {
    var oembed_url = 'http://backend.deviantart.com/oembed?url=' + encodeURIComponent(url) + '&format=jsonp&callback=?';
    request = $.getJSON(oembed_url, function(data) {
      images = data;
    }).complete(function() {
      var a = $('<a>');
      var img = $('<img>');
      var div = $('<div class="item uncached">');

      var title = '"' + images.title + '" by ' + images.author_name;

      img.attr('src', images.thumbnail_url);
      img.attr('alt', title);

      a.attr('href', url);
      a.attr('title', title);

      if (images.thumbnail_url != undefined && images.title != undefined) {
        a.append(img);
        div.append(a);
        $('#container').imagesLoaded(function(){ $('#container').isotope('insert', div); });
      } else {
        // Not an image deviation.
        // console.log(images);
      }
    });
  } else if (flickr_re.test(url)) {
    var oembed_url = 'http://www.flickr.com/services/oembed?url=' + encodeURIComponent(url) + '&format=json&&maxwidth=300&jsoncallback=?';
    request = $.getJSON(oembed_url, function(data) {
      images = data;
    }).complete(function() {
      var a = $('<a>');
      var img = $('<img>');
      var div = $('<div class="item uncached">');

      var title = '"' + images.title + '" by ' + images.author_name;
      if (images.thumbnail_url != undefined) {
        var image_url = images.thumbnail_url.replace(/\_s\./, "_n.");
        img.attr('src', image_url);
        img.attr('alt', title);
      }

      a.attr('href', url);
      a.attr('title', title);

      if (images.thumbnail_url != undefined && images.title != undefined) {
        a.append(img);
        div.append(a);
        $('#container').imagesLoaded(function(){ $('#container').isotope('insert', div); });
      } else {
        // Not a flickr photo.
        // console.log(images);
      }
    });
  } else {
    console.log("Unkown: " + url);
  }

  requests.push(request);
});

console.log(requests.length);

$.when(requests).done(function(){
  $('#container').imagesLoaded(function(){
    console.log('images loaded, requests done');
    $('.uncached').each(function(index, value) {
      console.log(value);
      // $.post('/cache', { favorite: ""
    });
  });
});
