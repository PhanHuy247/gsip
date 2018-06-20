package AplDefine;

use strict;

our $version = "0.1";
our $LogKind = {
	LOG_REQUEST => {Code => 101,Description => 'LOG_REQUEST'},
	LOG_FAIL_BACK => {Code => 102,Description => 'LOG_REQUEST'},
	LOG_STATUS_CHANGE => {Code => 103,Description => 'LOG_REQUEST'},
};
our $Error = {
	HTTP_CONNECT_ERROR => {Code => 20001,Description => 'HTTP_CONNECT_ERROR'},
	HTTP_STATUS_ERROR => {Code => 20001,Description => 'HTTP_STATUS_ERROR'},
	XML_PARSE_ERROR => {Code => 20101,Description => 'XML_PARSE_ERROR'},
	DATABASE_CONNECT_ERROR => {Code => 20102,Description => 'DATABASE_CONNECT_ERROR'},
	DATABASE_EXEC_ERROR => {Code => 20103,Description => 'DATABASE_EXEC_ERROR'},
	DATABASE_EXEC_ERROR => {Code => 20104,Description => 'XML_FORMAT_ERROR'},
	};
our $HangupOnStar = "HangupOnStar";
our $NoHangupOnStar = "NoHangupOnStar";

our $CALL_BUSY = 1;
our $CALL_BUSY_STR = "call_busy";
our $CALL_CANCEL = 2;
our $CALL_CANCEL_STR = "call_cancel";
our $END_CALL_BY_MALE = 3;
our $END_CALL_BY_MALE_STR = "end_call_by_male";
our $END_CALL_BY_FEMALE = 4;
our $END_CALL_BY_FEMALE_STR = "end_call_by_female";
our $END_CALL_BY_NOT_ENOUGH_POINT = 5;
our $END_CALL_BY_NOT_ENOUGH_POINT_STR = "end_call_by_not_enough_point";
our $END_CALL_OTHERS = 6;
our $END_CALL_OTHERS_STR = "end_call_others";

our $VIDEO_CALL = 16;
our $VIDEO_CALL_STR = "video_call";
our $VOICE_CALL = 15;
our $VOICE_CALL_STR = "voice_call";
1;
