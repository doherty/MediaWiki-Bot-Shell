use strict;
use warnings;
package MediaWiki::Bot::Shell;
# ABSTRACT: a shell interface to your MediaWiki::Bot

use base qw(Term::Shell);
use MediaWiki::Bot '3.1.6';
use Config::General qw(ParseConfig);
use Term::Prompt;
use IO::Pager;

my $u; # Will be a MW::B object

sub prompt_str {
    return (
        $u
        ? ( $u->{'host'} eq 'secure.wikimedia.org'
            ? $u->{'username'} . '>'
            : $u->{'username'} . '@' . $u->domain_to_db($u->{'host'}) . '>')
        : 'perlwikibot>'
    );
}

# At shell startup - right before cmdloop()
sub preloop {
    # Log in
    if (-r "$ENV{'HOME'}/.perlwikibot-shell.conf") {
        my %main = ParseConfig (
            -ConfigFile     => "$ENV{'HOME'}/.perlwikibot-shell.conf",
            -AutoTrue       => 1,
            -UTF8           => 1,
        );

        $u = MediaWiki::Bot->new({
            login_data => { username => $main{'username'},
                            password => $main{'password'},
                            do_sul   => 1,
                        },
            protocol   => $main{'protocol'},
            host       => $main{'host'},
            path       => $main{'path'},
#            debug      => 1,
        });
        if ($u) {
            print "Successfully logged into: $main{'username'}\n";
        }
        else {
            print "Couldn't log into $main{'username'}\n";
        }
    }
    else {
        my $username = prompt('x', 'Bot account name:', '', '');
        my $password = prompt('p', 'Password:', '', '');
        $u = MediaWiki::Bot->new({
            login_data => { username => $username,
                            password => $password,
                            do_sul   => 1
                        },
#            debug => 1,
        });
        if ($u) {
            print "Successfully logged into: $username\n";
        }
        else {
            print "Couldn't log into $username\n";
        }
    }
}

sub postloop {
    my $success = $u->logout();
    print ($success ? "Logged out\n" : "Couldn't log out\n");
}

sub run_delete  {
    my ($o, @args) = @_;
    my $page    = shift(@args);
    my $summary = shift(@args) || 'Vandalism';
    if (scalar @args != 0) {
        print <<"END";
Looks like you didn't quote your command properly
Are you sure you meant to delete [[$page]] with the reason
"$summary"?

Here are the rest of your arguments:
@args
END
        my $abort = prompt('y', 'Abort?', '', 'y');
        return 1 if $abort;
    }

    my $success = $u->delete($page, $summary);#print "delete($page, $summary)\n";
    if ($success) {
        print "Deletion successful\n";
    }
    else {
        print "Deletion failed:\n"
            . "    " . $u->{'error'}->{'details'}
            . "\n";
    }
}
sub smry_delete {
    return 'delete a page';
}
sub help_delete {
    return <<'END';
Deletes a page (requires a sysop account)

    delete "The page I want to delete" "My reason for deleting"
END
}

sub run_set_wiki {
    my ($o, @args) = @_;
    my $domain = shift(@args);
    my $path   = shift(@args);

    if (!$domain) {
        $domain = prompt('x', 'Switch to what domain?', '', '');
    }

    my $success;
    if ($domain eq 'secure.wikimedia.org') {
        $path = prompt('x', 'What path on secure.wikimedia.org?', '', '') unless defined($path);
        $success = $u->set_wiki({
            protocol => 'https',
            host     => $domain,
            path     => $path,
        });
    }
    else {
        $success = $u->set_wiki({ host => $domain, path => $path });
    }

    if ($success) {
        print "Switched successfully\n";
    }
    else {
        print "Couldn't switch wiki\n";
    }
}
sub smry_set_wiki {
    return 'switch to another wiki';
}
sub help_set_wiki {
    return <<'END';
Switches to a new wiki

    set_wiki meta.wikimedia.org
    set_wiki secure.wikimedia.org wikipedia/meta/w
END
}

sub run_debug {
    my ($o, @args) = @_;
    my $debug = shift(@args);

    my $on  = "Debug output on\n";
    my $off = "Debug output off\n";
    if (!defined($debug)) {
        $u->{'debug'} = 1;
        print $on;
    }
    elsif (defined($debug) and $debug =~ m/^(y|yes|1|true|on)$/i) {
        $u->{'debug'} = 1;
        print $on;
    }
    elsif (defined($debug) and $debug =~ m/^(n|no|0|false|off)$/i) {
        $u->{'debug'} = 0;
        print $off;
    }
    else {
        $debug = prompt('y', 'Provide debug output?', '', 'n');
        $u->{'debug'} = $debug;
        print ($debug ? $on : $off);
    }

}
sub smry_debug {
    return 'switch debugging on or off';
}
sub help_debug {
    return <<'END';
Switches debugging on or off.

On, yes, true and 1 are accepted as true values.
Off, no, false and 0 are accepted as false values.
END
}

sub run_read {
    my ($o, @args) = @_;
    my $page = shift(@args);
    if (scalar @args != 0) {
        print <<"END";
Looks like you didn't quote your command properly.
Do you want to read [[$page]]?

Here are the rest of your arguments: @args
END
        my $abort = prompt('y', 'Abort?', '', 'y');
        return 1 if $abort;
    }

    my $text = $u->get_text($page);
    if (defined($text)) {
        # This seems to bork the shell, but Term::Shell's advertized page() doesn't work either
        local $STDOUT = new IO::Pager *STDOUT;
        print $text;
    }
    else {
        print "[[$page]] doesn't exist\n";
    }
}
sub smry_read {
    return 'read a wiki page';
}
sub help_read {
    return <<'END';
Read a wiki page

Fetch the wikitext of a page, and display it. We hope you have a
MediaWiki parser in your brain :)
END
}

1;

__END__
