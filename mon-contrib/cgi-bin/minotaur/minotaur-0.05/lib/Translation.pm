package Translation;

use strict;

# I developped this module with the version 5.004
# Perhaps it works with a smaller release
# Let me know about it !

#use 5.004;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use FileHandle;

require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT_OK = (
	'load',
	'translate',
	'language',
	'extractMessages',
	'availableLanguages'
);
$VERSION = '0.02';


# Preloaded methods go here.

sub load {
	my ($argv) = shift;
	my ($messageFileName, $messageFileHandle, @messagesInput, 
	    $line, $context);
	my (%dicoGlobal, $refDicoGlobal, %dico, $refDico, 
		$currentIndex, $index, $key, $defaultLanguage,
		$indexLoop);
	
	if (ref($argv)) {
		#print "called ref:[$argv]\n";
		$messageFileName = shift;
		$refDico = $argv;
		$currentIndex = $refDico->{'currentIndex'};
		$refDicoGlobal = $refDico->{'dicoGlobal'};
		#print "\$currentIndex=[$currentIndex]\n";
	}else{
		#print "called unref\n";
		$messageFileName = $argv;
		$refDico = \%dico;
		$currentIndex = 0;
	};
	
	$messageFileHandle =  new FileHandle "$messageFileName", O_RDONLY;

	unless (defined($messageFileHandle)) {
		warn "Can not open $messageFileName\, $!";
		return undef;
	}
	@messagesInput = <$messageFileHandle>;
	$messageFileHandle->close();
	
	$context = 'None';
	LINE: foreach $line (@messagesInput) {
		# ignore lines begining with nougth or more blanks followed bye a sharp "#"
		next if ($line =~ /^\s*#.*$/);
		# ignore blank lines 
		next if ($line =~ /^\s*$/);
		#print $line;
		
		CHOOSE_CONTEXT: {
			$line =~ /^\s*\@Languages\s*$/ and do {
				#print "### Context \@Languages\n";
				$context = 'Languages';
				next LINE;
			};
			$line =~ /^\s*\@Message\s*$/ and do {
				#print "### Context \@Message\n";
				$context = 'Message';
				$currentIndex++;
				next LINE;
			};
			$line =~ /^\s*\@.*$/ and do {
				#print "### Context \@Unknown\n";
				$context = 'Unknown';
				next LINE;
			};
			# same context
			$context = $context;			
		};
		chomp ($line);
		CASE_CONTEXT: {
			
			($context eq 'Languages') and do {
				my ($language, $default);
				($language, $default) = split(/\s+/, $line);
				#print "language=[$language] default=[$default]\n";
				if (defined($default)){
					if ($default eq 'default') {
						if ((defined($refDico->{'language'})) 
						     and ($refDico->{'language'} ne $language)) {
							warn "The default language is already defined with ", 
							     "[$refDico->{'language'}]\, now replaced with ",
								  "[$language] \, warn";
							
						};
						#$Translation::language = $language;
						$refDico->{'language'}=$language;
					};
				}
				next LINE;
			};
			
			($context eq 'Message') and do {
				my ($language, $message);
				$line =~ /^\s*(\w+)\s*:(.+)$/;
				($language, $message) = ($1, $2);
				#print "index=[$currentIndex] language=[$language] value=[$message]\n";
				$refDicoGlobal->{$currentIndex}{$language}=$message;
				$refDico->{'availableLanguages'}{$language}=0;
				next LINE;
			};
			
			($context eq 'Unknown') and do {
				
				warn "Can not understand the keyword context\, warn";
				next LINE;
			};			
		};
	}
	
	if ($context eq 'None') {
		warn "File $messageFileName do not seem a regular message file\, warn";
		return undef
	}

	$indexLoop = (defined($refDico->{'currentIndex'}) ? $refDico->{'currentIndex'}+1 : 1);
	
	
	foreach $index ($indexLoop .. scalar(keys(%$refDicoGlobal))) {
		my($language, $message);
		#print "index:[$index]\n";
		foreach $language ( keys %{ $refDicoGlobal->{$index} }){
			$message = $refDicoGlobal->{$index}{$language};
			#print "$language=[$message]\n";
			if (defined($refDico->{'messages'}{$message})
			    and ($refDico->{'messages'}{$message} ne $index)) {
				warn "The message [$message] already exists ",
				"with index [$refDico->{'messages'}{$message}]\n",
				"now replaced with index [$index]";
			}
			$refDico->{'messages'}{$message} = $index;
		};
	};
	$refDico->{'dicoGlobal'} = $refDicoGlobal;
	$refDico->{'currentIndex'} = $currentIndex;
	bless $refDico, 'Translation';
	return $refDico;
};



sub extractMessages {
	my ($dico, $language, $hash, @listMessage);
	$dico     = shift;
	$language  = shift;

	foreach $hash (values (%{ $dico->{dicoGlobal}})) {
		push (@listMessage, $hash->{$language});
	}
	return (@listMessage);
}

sub availableLanguages {
	my ($dico);
	$dico     = shift;

return keys (%{ $dico->{availableLanguages}});
}


sub translate {
  my ($dico, $language, $message, $traduc);
  
	$dico     = shift;
	$message  = shift;
	$language = @_ ? shift
		: $dico->{'language'} ;
	
	# Is not it beautiful ?
	#$traduc = $dico->{'dicoGlobal'}{$dico->{'messages'}{$message}}{$language};
	#print "traduc=[$traduc]\n";
		

#	 if (defined($dico->{'messages'})){
#		 print "\$dico->{'messages'} : [",$dico->{'messages'},"]\n";
#	 }
#
#	 if (defined($dico->{'dicoGlobal'})){
#		 print "\$dico->{'dicoGlobal'} : [",$dico->{'dicoGlobal'},"]\n";
#	 }
#
#	 if (defined($dico->{'messages'}{$message})){
#		 print "\$dico->{'messages'}{$message} : [",$dico->{'messages'}{$message},"]\n";
#	 }
#
#	 if (defined($dico->{'dicoGlobal'}{$dico->{'messages'}{$message}})){
#		 print "\$dico->{'dicoGlobal'}{\$dico->{'messages'}{$message}} : [",$dico->{'dicoGlobal'}{$dico->{'messages'}}{$message},"]\n";
#	 }
	
	
			
	SWITCH: {
		unless (defined($dico->{'dicoGlobal'}{$dico->{'messages'}{$message}})){
			warn  "could not translate [$message]\, left as is";
			$traduc = $message;
			#print "$traduc\n";
			last SWITCH;
		};
		unless (defined($dico->{'dicoGlobal'}{$dico->{'messages'}{$message}}{$language})) {
			unless(defined($dico->{'dicoGlobal'}{$dico->{'messages'}{$message}}{$dico->{'language'}})){
				warn  "could not translate [$message]\, left as is";
				$traduc = $message;
				#print "$traduc\n";
				last SWITCH;
			};
			$traduc = $dico->{'dicoGlobal'}{$dico->{'messages'}{$message}}{$dico->{'language'}};
			warn "could not translate [$message] in language [$language]\n",
			"replaced by [$traduc] in language [$dico->{'language'}]";	
			#print "$traduc\n";
			last SWITCH;
		};
		$traduc = $dico->{'dicoGlobal'}{$dico->{'messages'}{$message}}{$language};
		#print "$traduc\n";
	}
  return($traduc);
  
};

sub language {
	my $dico = shift;
	@_ ? $dico->{'language'} = shift
		: $dico->{'language'};
	#return $$dico{'language'};
};

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Translation - Perl extension for simple a simple internationalisation interface

=head1 SYNOPSIS

  use Translation ('load', 'quit', 'translate', 'language');

  $dico = load("/path/foo.dico");
  print  $dico->translate("You got beautifull eyes you know","French" );
  
  $dico->language("javanais");
  print  $dico->translate("You got beautifull eyes you know");
  
  $dico->load("/path/foo2.dico");
  print $dico->translate("I know");
  
  undef($dico);

=head1 DESCRIPTION

Translation::load() loads a dictionnary.

Translation::language() gives or sets the default language.

Translation::translate() translates the message.

Loading a corpus:

you can append several corpus in the same object like this:

$dico  =  load("/path/foo1.dico");
$dico->load("/path/foo2.dico");
$dico->load("/path/foo3.dico");

If two or identical messages are loaded a warning appears on stderr.

Unloading a corpus:

unset($dico);

Message translation:

1) With 2 parameters

	$dico->translate($message, $language)
            
returns the translation of the message ``$message'' in the language 
``$language'' if this translation exists.

else, returns the translation of the message ``$message'' in the
default language  ``$dico->language()''if this translation exists.

else, returns the translation of the message ``$message'' itself.

2) With only one parameter

	$dico->translate($message)

returns the translation of the message ``$message'' in the
default language  ``$dico->language()''if this translation exists.

else, return the translation of the message ``$message'' itself.

Then, in every case, a pertinent message is returned ! 


Default language:

1) with no parameter

	$toto = $dico->language()
            
returns the default language.

2) with one parameter
 
	$dico->language($language)
            
    set the default language with ``$language''.

=head1 WRITING A CORPUS

You have to edit it by hand. Here is a self-explain example:

 
 ######### multilingual configuration file example ###########
 
 
 # Lines begining with a sharp "#" are ignored.
 # Blank lines are ignored.
 
 # Section languages
 # "@Languages" is the language identifier keyword
 # item are alphanumerics
 # [a-zA-Z0-9_]+ 
 # 
 # keyword : "default" : default language
 # keyword "default" is facultative.
 # 
 # The section languages is also facultative.
 
 @Languages
 Francais        
 English         default
 Deutsch         
 
 # "@Message" is a keyword noticing the end  of the precedent 
 # message and the begining of "linked" messages 
 
 
 # Everything that is after the colon takes part in the message,
 # even blank caracters, until the end of line caracter which is
 # not included.
 
 # language order is not important, it can vary.
 
 # It is not necessary to translate each message in every
 # language.
 # If the translation does not exist the default language 
 # message is used.
 # If the default language does not exist the same message is used.
  
  
 @Message
 Francais :Aucun processus actif
 English  :No process running
 Deutsch  :Nicht hinauslehnen
 Espagnol :Oy tu, el processor matador disastrosita
 Italiano :Li proicessechi improbabile, ecco ...
 
 @Message
 Francais :Ce warning est normal aussi
 English  :This warning is normal too
 Deutsch  :Kartofen
 Espagnol :No lo se
 Italiano :?????
 japan    :????????
 
 ######### End of example ###########


=head1 AUTHOR

Gilles LAMIRAL, lamiral@mail.dotcom.fr

=head1 SEE ALSO

perl(1).

=cut
