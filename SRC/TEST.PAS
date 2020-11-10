uses scr,scrui;


var
	sitem:integer;
	w:word;

begin
	sitem:=0;
	while true do begin
		w:=scrui.vmenu(10,10, 10, 5, $70, $07, '1111'+#$0a+'2222'+#$0a+'3'+#$0a+'44', sitem);
		if w = K_ESC then break;
	end;
end.