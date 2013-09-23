/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
extern IdTable  idtable;
extern IntTable inttable;
extern StrTable stringtable;

%}

/*
 * Define names for regular expressions here.
 */
INT_CONST       [0-9]+
TYPEID          [A-Z][0-9a-zA-Z_]*
OBJECTID        [a-z][0-9a-zA-Z_]*
ASSIGN          "<-"
LE              "<="
DARROW          "=>"

%x COMMENT STR 
  int nesting = 0;
  int str_len = 0; 
  int str_nul = 0;
%%

 /* 
  *  INTEGER CONST
  */

{INT_CONST} {
  cool_yylval.symbol = inttable.add_string(yytext, yyleng);
  return (INT_CONST);
}
  
 /*
  *  Nested comments
  */

"*)" {
  cool_yylval.error_msg = "Unmatched *)";
  return (ERROR);
}

"(*" { 
  BEGIN COMMENT; 
  nesting = 1; /* initialized saved string */
}

<COMMENT><<EOF>> {
  cool_yylval.error_msg = "EOF in comment";
  BEGIN INITIAL;
  return (ERROR);
}

<COMMENT>"(*" { 
  nesting++; /* add to saved string for parser */ 
  /*printf("start commnet, nest = %d\n", nesting);*/
}

<COMMENT>"*)" { 
  if(--nesting <=0 ) {
    BEGIN INITIAL;
  }
}

<COMMENT>\n {
  curr_lineno++;
}

<COMMENT>. { 
   /* add to saved string for parser */ 
}

"--".* {
  /* comment */
}

 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return (DARROW); }
{ASSIGN}                { return (ASSIGN); }
{LE}                    { return (LE); }

 /*
  * The single-character symbols.
  */
"+"                     { return ('+'); }
"-"                     { return ('-'); }
"*"                     { return ('*'); }
"/"                     { return ('/'); }
"~"                     { return ('~'); }
"<"                     { return ('<'); }
"="                     { return ('='); }
";"                     { return (';'); }
"."                     { return ('.'); }
","                     { return (','); }
":"                     { return (':'); }
"@"                     { return ('@'); }
"("                     { return ('('); }
")"                     { return (')'); }
"{"                     { return ('{'); }
"}"                     { return ('}'); }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

[cC][lL][aA][sS][sS]                 { return (CLASS); }
[eE][lL][sS][eE]                     { return (ELSE); }
[fF][iI]                             { return (FI); }
[iI][fF]                   	     { return (IF); }
[iI][nN]                  	     { return (IN); }
[iI][nN][hH][eE][rR][iI][tT][sS]     { return (INHERITS); }
[lL][eE][tT]                         { return (LET); }
[lL][oO][oO][pP]                     { return (LOOP); }
[pP][oO][oO][lL]                     { return (POOL); }
[tT][hH][eE][nN]                     { return (THEN); }
[wW][hH][iI][lL][eE]                 { return (WHILE); }
[cC][aA][sS][eE]                     { return (CASE); }
[eE][sS][aA][cC]                     { return (ESAC); }
[oO][fF]                             { return (OF); }
[nN][eE][wW]                         { return (NEW); }
[iI][sS][vV][oO][iI][dD]             { return (ISVOID); }
[nN][oO][tT]                         { return (NOT); }
 
 /*
  * Bool Const
  */
t[rR][uU][eE] {
  cool_yylval.boolean = true; 
  return (BOOL_CONST); 
}

f[aA][lL][sS][eE] {
  cool_yylval.boolean = false; 
  return (BOOL_CONST);
}

 /*
  * Class Identifiers and Object Identifiers
  */
{TYPEID} {
  cool_yylval.symbol = idtable.add_string(yytext, yyleng);
  return (TYPEID);
}

{OBJECTID} {
  cool_yylval.symbol = idtable.add_string(yytext, yyleng);
  return (OBJECTID);
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
\"  {
  BEGIN STR; 
  string_buf_ptr = string_buf;
  str_len = 0;
  str_nul = 0;
}
<STR>\" {
  BEGIN INITIAL;
  if (str_len >= MAX_STR_CONST)
  {
    cool_yylval.error_msg = "String constant too long";  
    return (ERROR);
  }
  else if (str_nul == 1)
  {
    cool_yylval.error_msg = "String contains null character";
    return (ERROR);
  }
  else
  {
    *string_buf_ptr = '\0';
    cool_yylval.symbol = stringtable.add_string(string_buf);
    return (STR_CONST);
  }
}
<STR>(\0) {
  str_nul = 1;
}
<STR>\n {
  cool_yylval.error_msg = "Unterminated string constant";
  BEGIN INITIAL;
  curr_lineno++;
  return (ERROR);
}
<STR>\\b {
  *string_buf_ptr = '\b';
  string_buf_ptr++;
  str_len++;
}
<STR>\\t {
  *string_buf_ptr = '\t';
  string_buf_ptr++;
  str_len++;
}
<STR>\\n {
  *string_buf_ptr = '\n';
  string_buf_ptr++;
  str_len++;
}
<STR>\\f {
  *string_buf_ptr = '\f';
  string_buf_ptr++;
  str_len++;
}
<STR><<EOF>> {
  cool_yylval.error_msg = "EOF in string constant";
  BEGIN INITIAL;
  return (ERROR);
}
<STR>\\. {
  if (yytext[1] == '\0')
  {
    str_nul = 1;
  }
  else
  {   
    *string_buf_ptr = yytext[1];
    string_buf_ptr++;
    str_len++;
  }
}
<STR>\\\n  {
  *string_buf_ptr = yytext[1];
  string_buf_ptr++;
  str_len++;
  curr_lineno++;
}
<STR>[^\\\n\"\0]+ {
  char *yptr = yytext;
     while ( *yptr )
        *string_buf_ptr++ = *yptr++;

  str_len += yyleng;
}

 /* 
  * White space
  */
\n {
  curr_lineno++;
}
[ \t\f\r\v]+ {
  /* whitespace*/
}

 /*
  * Invalid characters
  */
. {
    cool_yylval.error_msg = strdup(yytext);
    return (ERROR);  
}
%%
