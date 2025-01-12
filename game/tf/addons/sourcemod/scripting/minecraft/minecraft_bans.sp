/**
 * Copyright Andrew Betson.
 * Copyright Moonly Days.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

Handle	g_hCookie_IsBanned;
Handle	g_hCookie_BanReason;
Handle	g_hCookie_UnbanTime;
Handle	g_hCookie_NumBans;

bool	g_bIsBanned[ MAXPLAYERS + 1 ] = { false, ... };

void OnPluginStart_Bans()
{
	RegConsoleCmd( "sm_mc_banstatus", Cmd_MC_BanStatus, "Tell the calling player whether they're block-banned or not." );

	RegAdminCmd( "sm_mc_ban", Cmd_MC_Ban, ADMFLAG_BAN, "Ban a player from being able to build and break Minecraft blocks." );
	RegAdminCmd( "sm_mc_unban", Cmd_MC_Unban, ADMFLAG_UNBAN, "Allow a player to build and break Minecraft blocks again." );

	g_hCookie_IsBanned = RegClientCookie( "mc_isbanned", "Set when a player is banned or unbanned from building and breaking Minecraft blocks.", CookieAccess_Protected );
	g_hCookie_BanReason = RegClientCookie( "mc_banreason", "Why the player was banned from building and breaking Minecraft blocks.", CookieAccess_Protected );
	g_hCookie_UnbanTime = RegClientCookie( "mc_unbantime", "Time (Unix) for the player to be unbanned.", CookieAccess_Private );
	g_hCookie_NumBans = RegClientCookie( "mc_numbans", "Number of times the player has been banned from building or breaking Minecraft blocks.", CookieAccess_Private );
}

void OnClientCookiesCached_Bans( int nClientIdx )
{
	char szCookieValue[ 4 ];
	GetClientCookie( nClientIdx, g_hCookie_IsBanned, szCookieValue, sizeof( szCookieValue ) );

	g_bIsBanned[ nClientIdx ] = ( szCookieValue[ 0 ] != '\0' && StringToInt( szCookieValue ) );
}

void OnClientDisconnect_Bans( int nClientIdx )
{
	g_bIsBanned[ nClientIdx ] = false;
}

public Action Cmd_MC_BanStatus( int nClientIdx, int nNumArgs )
{
	if ( g_bIsBanned[ nClientIdx ] )
	{
		char szBanReason[ 179 ];
		GetClientCookie( nClientIdx, g_hCookie_BanReason, szBanReason, sizeof( szBanReason ) );

		CPrintToChat( nClientIdx, "%t", "MC_BanStatus_Banned", szBanReason );
	}
	else
	{
		CPrintToChat( nClientIdx, "%t", "MC_BanStatus_NotBanned" );
	}

	return Plugin_Handled;
}

public Action Cmd_MC_Ban( int nClientIdx, int nNumArgs )
{
	if ( nNumArgs < 3 )
	{
		CReplyToCommand( nClientIdx, "%t", "MC_Ban_Usage" );
		return Plugin_Handled;
	}

	char szArgs[ 256 ];
	GetCmdArgString( szArgs, sizeof( szArgs ) );

	char szTargetName[ 65 ];
	int nArgLen = BreakString( szArgs, szTargetName, sizeof( szTargetName ) );

	int nTargetClientIdx = FindTarget( nClientIdx, szTargetName, true );
	if ( nTargetClientIdx == -1 )
	{
		return Plugin_Handled;
	}

	char szBanLength[ 12 ];
	char szBanReason[ 179 ]; // ( 256 - 65 - 12 ) gives us 179 bytes for the reason.

	int nNextArgLen;
	if ( ( nNextArgLen = BreakString( szArgs[ nArgLen ], szBanLength, sizeof( szBanLength ) ) ) != -1 )
	{
		nArgLen += nNextArgLen;
		strcopy( szBanReason, sizeof( szBanReason ), szArgs[ nArgLen ] );
	}

	int nBanLength = StringToInt( szBanLength ) * 60;
	int nUnbanTime = GetTime() + nBanLength;

	g_bIsBanned[ nTargetClientIdx ] = true;
	CPrintToChat( nTargetClientIdx, "%t", "MC_Banned" );

	SetClientCookie( nTargetClientIdx, g_hCookie_IsBanned, "1" );
	SetClientCookie( nTargetClientIdx, g_hCookie_BanReason, szBanReason );

	char szUnbanTime[ 12 ];
	IntToString( nUnbanTime, szUnbanTime, sizeof( szUnbanTime ) );

	SetClientCookie( nTargetClientIdx, g_hCookie_UnbanTime, szUnbanTime );

	char szNumBans[ 2 ];
	GetClientCookie( nTargetClientIdx, g_hCookie_NumBans, szNumBans, sizeof( szNumBans ) );

	if ( szNumBans[ 0 ] == '\0' )
	{
		SetClientCookie( nTargetClientIdx, g_hCookie_NumBans, "1" );
	}
	else
	{
		int nNumBans = StringToInt( szNumBans );
		char szNewNumBans[ 2 ];
		IntToString( nNumBans + 1, szNewNumBans, sizeof( szNewNumBans ) );

		SetClientCookie( nTargetClientIdx, g_hCookie_NumBans, szNewNumBans );
	}

	Block_ClearPlayer( nTargetClientIdx );

	return Plugin_Handled;
}

public Action Cmd_MC_Unban( int nClientIdx, int nNumArgs )
{
	if ( nNumArgs > 1 )
	{
		CReplyToCommand( nClientIdx, "%t", "MC_Unban_Usage" );
		return Plugin_Handled;
	}

	char szArgs[ 256 ];
	GetCmdArgString( szArgs, sizeof( szArgs ) );

	int nTargetClientIdx = FindTarget( nClientIdx, szArgs, true );
	if ( nTargetClientIdx == -1 )
	{
		return Plugin_Handled;
	}

	g_bIsBanned[ nTargetClientIdx ] = false;
	CPrintToChat( nTargetClientIdx, "%t", "MC_Unbanned" );

	SetClientCookie( nTargetClientIdx, g_hCookie_IsBanned, "0" );
	SetClientCookie( nTargetClientIdx, g_hCookie_BanReason, "" );
	SetClientCookie( nTargetClientIdx, g_hCookie_UnbanTime, "" );

	return Plugin_Handled;
}

void CheckClientBan( int nClientIdx )
{
	int nCurrentTime = GetTime();

	char szUnbanTime[ 12 ];
	GetClientCookie( nClientIdx, g_hCookie_UnbanTime, szUnbanTime, sizeof( szUnbanTime ) );

	int nUnbanTime = StringToInt( szUnbanTime );
	if ( nUnbanTime <= nCurrentTime )
	{
		g_bIsBanned[ nClientIdx ] = false;
		SetClientCookie( nClientIdx, g_hCookie_IsBanned, "0" );
		SetClientCookie( nClientIdx, g_hCookie_BanReason, "" );
		SetClientCookie( nClientIdx, g_hCookie_UnbanTime, "" );

		// TODO(AndrewB): OnClientPostAdminCheck fires too early for this to actually get printed to the players chat.
//		CPrintToChat( nClientIdx, "%t", "MC_Unbanned" );
	}
}
