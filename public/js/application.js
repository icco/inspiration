$(document).foundation();
$('#container').isotope({ itemSelector : '.item' });
$('#container').isotope('shuffle');

$('.embed').each(function(index, value) {
  var url = $(value).data('embed');
  var oembed_url = 'http://backend.deviantart.com/oembed?url=' + encodeURIComponent(url) + '&format=jsonp&callback=?';
  $.getJSON(oembed_url, function(data) {
    images = data;
  }).complete(function() {
    var a = $('<a>');
    var img = $('<img>');
    var div = $('<div class="item">');

    img.attr('src', images.thumbnail_url);
    img.attr('alt', images.title);

    a.attr('href', url);
    a.attr('title', images.title);

    a.append(img);
    div.append(a);

    $('#container').imagesLoaded(function(){ $('#container').isotope('insert', div); });
  });
});
