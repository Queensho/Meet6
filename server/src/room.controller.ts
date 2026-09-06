import { Body, Controller, Delete, Get, Headers, Param, Post, Put, Query } from '@nestjs/common';

import { AuthService } from './auth.service';
import { GameRoomTestService } from './game-room-test.service';
import { ExtensionVoteDto, JoinQueueDto, RoomSelectionDto, SendRoomMessageDto } from './room.dto';
import { RoomService } from './room.service';
import { RoomsGateway } from './rooms.gateway';

@Controller('rooms')
export class RoomController {
  constructor(
    private readonly auth: AuthService,
    private readonly rooms: RoomService,
    private readonly realtime: RoomsGateway,
    private readonly gameRoomTest: GameRoomTestService,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  @Post('queue')
  async joinQueue(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: JoinQueueDto,
  ) {
    const result = await this.rooms.joinQueue(
      await this.userId(authorization),
      body.roomDurationMinutes ?? 15,
    ) as Record<string, any>;
    if (result.state === 'room' && result.room) {
      const roomId = (result.room as Record<string, any>).id?.toString();
      if (roomId) await this.realtime.broadcastRoomUpdate(roomId);
    }
    await this.realtime.broadcastQueueStatus();
    return result;
  }

  @Post('game-test')
  async createGameTestRoom(@Headers('authorization') authorization?: string) {
    const result = await this.gameRoomTest.create(await this.userId(authorization));
    const roomId = (result.room as Record<string, any>)?.id?.toString();
    if (roomId) await this.realtime.broadcastRoomUpdate(roomId);
    await this.realtime.broadcastQueueStatus();
    return result;
  }

  @Get('game/:roomId/state')
  async gameState(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
  ) {
    return this.gameRoomTest.state(await this.userId(authorization), roomId);
  }

  @Post('game/:roomId/statements')
  async gameStatements(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: { statements?: unknown; lieIndex?: unknown },
  ) {
    return this.gameRoomTest.submitStatements(
      await this.userId(authorization),
      roomId,
      body.statements,
      body.lieIndex,
    );
  }

  @Post('game/:roomId/vote')
  async gameVote(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: { choice?: unknown },
  ) {
    return this.gameRoomTest.vote(
      await this.userId(authorization),
      roomId,
      body.choice,
    );
  }

  @Post('game/:roomId/next')
  async gameNext(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
  ) {
    return this.gameRoomTest.nextRound(await this.userId(authorization), roomId);
  }

  @Get('queue')
  async queueStatus(@Headers('authorization') authorization?: string) {
    return this.rooms.queueStatus(await this.userId(authorization));
  }

  @Delete('queue')
  async cancelQueue(@Headers('authorization') authorization?: string) {
    const result = await this.rooms.cancelQueue(await this.userId(authorization));
    await this.realtime.broadcastQueueStatus();
    return result;
  }

  @Get(':roomId')
  async room(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
  ) {
    return this.rooms.getRoom(await this.userId(authorization), roomId);
  }

  @Get(':roomId/messages')
  async messages(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Query('after') after?: string,
  ) {
    return this.rooms.messages(
      await this.userId(authorization),
      roomId,
      Number.parseInt(after ?? '0', 10) || 0,
    );
  }

  @Post(':roomId/messages')
  async sendMessage(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: SendRoomMessageDto,
  ) {
    return this.rooms.sendMessage(await this.userId(authorization), roomId, body.body);
  }

  @Put(':roomId/extension-vote')
  async extensionVote(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: ExtensionVoteDto,
  ) {
    const result = await this.rooms.voteExtension(await this.userId(authorization), roomId, body.vote);
    await this.realtime.broadcastRoomUpdate(roomId);
    return result;
  }

  @Put(':roomId/selection')
  async selection(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: RoomSelectionDto,
  ) {
    return this.rooms.submitSelection(await this.userId(authorization), roomId, body.selectedUserId);
  }

  @Get(':roomId/selection-result')
  async selectionResult(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
  ) {
    return this.rooms.selectionResult(await this.userId(authorization), roomId);
  }
}
