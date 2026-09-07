import { createHash } from 'crypto';
import { BadRequestException, Body, Controller, Delete, ForbiddenException, Get, Headers, Param, Post, Put, Query } from '@nestjs/common';

import { AuthService } from './auth.service';
import { GameRoomTestService } from './game-room-test.service';
import { InfrastructureService } from './infrastructure.service';
import { RedFlagGameService } from './red-flag-game.service';
import { ExtensionVoteDto, JoinQueueDto, RoomSelectionDto, SendRoomMessageDto } from './room.dto';
import { RoomService } from './room.service';
import { RoomsGateway } from './rooms.gateway';

@Controller('rooms')
export class RoomController {
  private static readonly GAME_FINISH_TEST_PHONE_HASH =
    '80340dec2efb640dbb56d3cd0234a589f4fffc6d79384cd2570377e6384d075d';

  constructor(
    private readonly auth: AuthService,
    private readonly rooms: RoomService,
    private readonly realtime: RoomsGateway,
    private readonly gameRoomTest: GameRoomTestService,
    private readonly redFlagGame: RedFlagGameService,
    private readonly infra: InfrastructureService,
  ) {}

  private async userId(authorization?: string) {
    return (await this.auth.userIdFromAuthorization(authorization)).userId;
  }

  private async assertGameFinishTester(userId: string) {
    const result = await this.infra.db.query<{ phone_e164: string }>(
      `select phone_e164 from users where id=$1 and status='active' limit 1`,
      [userId],
    );
    const phone = result.rows[0]?.phone_e164?.trim() ?? '';
    const hash = createHash('sha256').update(phone).digest('hex');
    if (hash !== RoomController.GAME_FINISH_TEST_PHONE_HASH) {
      throw new ForbiddenException('Bu kullanıcı için oyun bitirme test yetkisi yok.');
    }
  }

  @Post('queue')
  async joinQueue(@Headers('authorization') authorization: string | undefined, @Body() body: JoinQueueDto) {
    const result = await this.rooms.joinQueue(await this.userId(authorization), body.roomDurationMinutes ?? 15) as Record<string, any>;
    if (result.state === 'room' && result.room) {
      const roomId = (result.room as Record<string, any>).id?.toString();
      if (roomId) await this.realtime.broadcastRoomUpdate(roomId);
    }
    await this.realtime.broadcastQueueStatus();
    return result;
  }

  @Post('game-test')
  async createGameTestRoom(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: { gameKey?: string },
  ) {
    const userId = await this.userId(authorization);
    const gameKey = body?.gameKey?.toString() ?? 'two_truths_one_lie';
    const result = gameKey === 'red_flag_green_flag'
      ? await this.redFlagGame.create(userId)
      : await this.gameRoomTest.create(userId);
    const roomId = (result.room as Record<string, any>)?.id?.toString();
    if (roomId) await this.realtime.broadcastRoomUpdate(roomId);
    await this.realtime.broadcastQueueStatus();
    return result;
  }

  @Post('game/:roomId/force-finish')
  async forceFinishGame(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: { gameKey?: string },
  ) {
    const userId = await this.userId(authorization);
    await this.assertGameFinishTester(userId);
    const gameKey = body?.gameKey?.toString() ?? '';

    if (gameKey === 'red_flag_green_flag') {
      const svc = this.redFlagGame as any;
      await svc.assertMember(userId, roomId);
      const state = svc.games.get(roomId);
      if (!state) throw new BadRequestException('Red Flag / Green Flag oyun durumu bulunamadı.');

      while (state.questionIndex < state.questions.length) {
        const question = state.questions[state.questionIndex];
        if (!state.answers.some((round: any) => round.questionId === question.id)) {
          const choices: Record<string, 'red' | 'green'> = {};
          for (const player of state.players) {
            choices[player.id] = state.choices[player.id] ?? svc.botChoice(player.id, question.id);
          }
          state.answers.push({ questionId: question.id, choices });
        }
        if (state.questionIndex >= state.questions.length - 1) break;
        state.questionIndex += 1;
        state.choices = {};
      }

      state.phase = 'final';
      state.phaseEndsAt = new Date();
      await svc.buildSuggestions(state);
      return svc.view(state, String(userId));
    }

    if (gameKey != '' && gameKey !== 'two_truths_one_lie') {
      throw new BadRequestException('Bu oyun için test bitirme desteklenmiyor.');
    }

    const svc = this.gameRoomTest as any;
    await svc.assertMember(userId, roomId);
    const state = svc.games.get(roomId);
    if (!state) throw new BadRequestException('Mini oyun durumu bulunamadı.');

    while (state.roundIndex < 10) {
      if (!state.round.resolved) {
        if (state.round.statements.length !== 3) {
          state.round.statements = svc.botStatements(state.roundIndex);
          state.round.lieIndex = 2;
        }
        for (const player of state.players) {
          if (player.id === state.round.ownerUserId) continue;
          state.round.votes[player.id] ??= (Number(player.id) + state.roundIndex) % 3;
        }

        const counts = [0, 0, 0];
        for (const vote of Object.values(state.round.votes) as number[]) counts[vote]++;
        const correctUserIds = state.players
          .filter((player: any) =>
            player.id !== state.round.ownerUserId &&
            state.round.votes[player.id] === state.round.lieIndex)
          .map((player: any) => player.id);

        state.round.resolved = true;
        state.round.result = {
          lieIndex: state.round.lieIndex,
          correctUserIds,
          voteCounts: counts,
        };
        state.completedRounds.push({
          ownerUserId: state.round.ownerUserId,
          lieIndex: state.round.lieIndex,
          votes: { ...state.round.votes },
        });
      }

      if (state.roundIndex >= 9) break;
      state.roundIndex += 1;
      state.round = svc.round(state.players, state.roundIndex);
    }

    state.finished = true;
    await svc.buildSuggestions(state);
    return svc.view(state, String(userId));
  }

  @Get('game/:roomId/state')
  async gameState(@Headers('authorization') authorization: string | undefined, @Param('roomId') roomId: string) {
    return this.gameRoomTest.state(await this.userId(authorization), roomId);
  }

  @Post('game/:roomId/statements')
  async gameStatements(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: { statements?: unknown; lieIndex?: unknown },
  ) {
    return this.gameRoomTest.submitStatements(await this.userId(authorization), roomId, body.statements, body.lieIndex);
  }

  @Post('game/:roomId/vote')
  async gameVote(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: { choice?: unknown },
  ) {
    return this.gameRoomTest.vote(await this.userId(authorization), roomId, body.choice);
  }

  @Post('game/:roomId/next')
  async gameNext(@Headers('authorization') authorization: string | undefined, @Param('roomId') roomId: string) {
    return this.gameRoomTest.nextRound(await this.userId(authorization), roomId);
  }

  @Get('game/:roomId/red-flag/state')
  async redFlagState(@Headers('authorization') authorization: string | undefined, @Param('roomId') roomId: string) {
    return this.redFlagGame.state(await this.userId(authorization), roomId);
  }

  @Post('game/:roomId/red-flag/choice')
  async redFlagChoice(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: { choice?: unknown },
  ) {
    return this.redFlagGame.choose(await this.userId(authorization), roomId, body.choice);
  }

  @Post('game/:roomId/red-flag/final-choice')
  async redFlagFinalChoice(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Body() body: { choice?: unknown },
  ) {
    return this.redFlagGame.finalChoice(await this.userId(authorization), roomId, body.choice);
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
  async room(@Headers('authorization') authorization: string | undefined, @Param('roomId') roomId: string) {
    return this.rooms.getRoom(await this.userId(authorization), roomId);
  }

  @Get(':roomId/messages')
  async messages(
    @Headers('authorization') authorization: string | undefined,
    @Param('roomId') roomId: string,
    @Query('after') after?: string,
  ) {
    return this.rooms.messages(await this.userId(authorization), roomId, Number.parseInt(after ?? '0', 10) || 0);
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
  async selectionResult(@Headers('authorization') authorization: string | undefined, @Param('roomId') roomId: string) {
    return this.rooms.selectionResult(await this.userId(authorization), roomId);
  }
}
