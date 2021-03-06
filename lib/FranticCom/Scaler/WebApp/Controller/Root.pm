package FranticCom::Scaler::WebApp::Controller::Root;
use Moose;
use namespace::autoclean;
use Try::Tiny;
use FranticCom::Scaler;
use IO::File;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(namespace => '');

has 'scaler' => ( is => 'ro', default => sub { FranticCom::Scaler->new } );

sub get_config : Private {
    my ( $self, $c, $id ) = @_;
    $id = 'none' unless $id;
    return {
        image_host => $self->scaler->image_host . "/$id",
        max_retries => $self->scaler->max_retries,
        retry_delay => $self->scaler->retry_delay,
        trigger_url => $c->uri_for_action('/index_trigger',$id)
    };
}

sub index_trigger_options : Path Args(1) Method('OPTIONS') {
    my ( $self, $c, $id ) = @_;
    $c->res->header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    $c->res->status(204);
}

sub index_trigger : Path Args(1) Method('POST') {
    my ( $self, $c, $id ) = @_;
    my $params = $c->req->params; $params->{id} = $id;
    $c->model('Worker')->scaler($params);
    $c->res->status(204);
}

sub index_trigger_block : Path Args(1) Method('GET') {
    my ( $self, $c, $id ) = @_;
    my $params = $c->req->params; $params->{id} = $id;
    my $resp = $c->model('Worker')->scaler_block($params);
    if ($resp) {
        $c->res->redirect($resp->{url},301);
    } else {
        $c->res->status(503);
        $c->res->header('Retry-After' => 5);
        $c->res->body('');
    }
}

sub index_get_js : Path('js') Args(1) Method('GET') {
    my ( $self, $c, $version ) = @_;
    $c->detach('unsupported_version') unless ( $version && $version eq '1' );
    my $full_path = $c->path_to( 'root','assets','js','scaler.js' );
    my $fh = IO::File->new( $full_path, 'r' );
    if ( defined $fh ) {
        binmode $fh;
        $c->res->body( $fh );
        $c->res->header('Content-Type' => 'application/javascript');
    } else {
        $c->detach('not_found');
    }
}

sub index_get_js_legacy : Path('1') Args(0) Method('GET') {
    my ( $self, $c ) = @_;
    $c->detach('index_get_js',[1]);
}

sub default : Path {
    my ( $self, $c ) = @_;
    $c->detach('not_found');
}

sub unsupported_version : Private {
    my ( $self, $c ) = @_;
    $c->res->status(404);
    $c->res->body('unsupported version');
}

sub not_found : Private {
    my ( $self, $c ) = @_;
    $c->res->status(404);
    $c->res->body('not found');
}

sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;
    $c->res->header('Access-Control-Allow-Origin', $c->req->header('Origin'));
}

__PACKAGE__->meta->make_immutable;

1;
