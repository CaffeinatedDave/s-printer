$(function() {
    options();
});

function options() {
    $.ajax({
        dataType: "json",
        url: "/game"
    }).done(function(data, textStatus, jqXHR){
        $('#left .panel-title').html(data.left.title);
        $('#left .description').html(data.left.description);
        $('#left button').data('id', data.left.id).click(function() {
            vote('#left');
        });;

        $('#right .panel-title').html(data.right.title);
        $('#right .description').html(data.right.description);
        $('#right button').data('id', data.right.id).click(function() {
            vote('#right');
        });
        $('#vote').data('uuid', data.uuid);

        $('#right').transition({
            x: 0,
            opacity: 1,
            duration: 500,
            easing: 'out'
        });
        $('#left').transition({
            x: 0,
            opacity: 1,
            duration: 500,
            easing: 'out',
        });
    });
}

function vote(e) {

    $(".panel").not(e).transition({
        opacity: 0,
        duration: 500,
        easing: 'out',
        complete: function() {
            $.ajax({
                method: "POST",
                dataType: "json",
                contentType: "application/json;",
                url: "/game/vote",
                processData: false,
                data: JSON.stringify({'vote': $(e + ' button').data('id'), 'uuid': $('#vote').data('uuid')})
            }).always(function() {
                $(".panel button").unbind();
                $("#left").css({x: '-1000px'});
                $("#right").css({x: '1000px'});
                options();
            })
        }
    });

    $(e +".panel").transition({
        opacity: 1,
        duration: 500,
        easing: 'out'
    });

}
