$(document).foundation();
$('#container').isotope({ itemSelector : '.item' });
$('#container').isotope('shuffle');

$('.embed').each(function(index, value) {
  var url = $(value).data('embed');

  var re = /http\:\/\/dribbble.com\/shots\//;
  if (re.test(url)) {
    var oembed_url = 'http://api.dribbble.com/shots/' + url.replace(re, "") + '?callback=?';
    $.getJSON(oembed_url, function(data) {
      images = data;
    }).complete(function() {
      var a = $('<a>');
      var img = $('<img class="dribbble">');
      var div = $('<div class="item">');

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
  } else {
    var oembed_url = 'http://backend.deviantart.com/oembed?url=' + encodeURIComponent(url) + '&format=jsonp&callback=?';
    $.getJSON(oembed_url, function(data) {
      images = data;
    }).complete(function() {
      var a = $('<a>');
      var img = $('<img>');
      var div = $('<div class="item">');

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
  }
});
