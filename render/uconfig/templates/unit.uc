{%
	/* load zoneinfo from json */
	let zoneinfo = json(fs.readfile('/usr/share/ucode/uconfig/zoneinfo.json') || '{}');

	/* resolve zoneinfo name to TZ */
	if (unit.timezone) {
		if (zoneinfo[unit.timezone])
			unit.timezone = zoneinfo[unit.timezone].iso2;
		else
			warn('timezone is unknown');
	}

	/* set the password */
	shell.password(unit.password);

	/* force the restart of the led script */
	if (exists(unit, 'leds_active'))
		services.set_enabled('led', 'restart');
-%}
# Configure the unit/system
set system.@system[-1].ttylogin={{ b(unit.tty_login) }}
{%	if (unit.hostname): %}
set system.@system[-1].hostname={{ s(unit.hostname) }}
{%	endif;
	if (unit.timezone): %}
set system.@system[-1].timezone={{ s(unit.timezone) }}
{%	endif %}
set system.@system[-1].leds_off={{ b(!unit.leds_active) }}
