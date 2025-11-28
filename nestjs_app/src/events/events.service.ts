import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Event } from './event.entity';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';

@Injectable()
export class EventsService {
  constructor(
    @InjectRepository(Event)
    private eventsRepository: Repository<Event>,
  ) {}

  // 활성화된 이벤트 목록 조회 (사용자용)
  async findActiveEvents(): Promise<Event[]> {
    return this.eventsRepository.find({
      where: { isActive: true },
      order: { createdAt: 'DESC' },
    });
  }

  // 전체 이벤트 목록 조회 (관리자용)
  async findAll(): Promise<Event[]> {
    return this.eventsRepository.find({
      order: { createdAt: 'DESC' },
    });
  }

  // 이벤트 상세 조회
  async findOne(id: number): Promise<Event | null> {
    return this.eventsRepository.findOne({ where: { id } });
  }

  // 이벤트 생성
  async create(createEventDto: CreateEventDto): Promise<Event> {
    const event = this.eventsRepository.create({
      title: createEventDto.title,
      content: createEventDto.content,
      startDate: createEventDto.startDate ? new Date(createEventDto.startDate) : null,
      endDate: createEventDto.endDate ? new Date(createEventDto.endDate) : null,
      isActive: createEventDto.isActive !== undefined ? createEventDto.isActive : true,
    });
    return this.eventsRepository.save(event);
  }

  // 이벤트 수정
  async update(id: number, updateEventDto: UpdateEventDto): Promise<Event> {
    const event = await this.findOne(id);
    if (!event) {
      throw new Error('이벤트를 찾을 수 없습니다.');
    }

    if (updateEventDto.title !== undefined) {
      event.title = updateEventDto.title;
    }
    if (updateEventDto.content !== undefined) {
      event.content = updateEventDto.content;
    }
    if (updateEventDto.startDate !== undefined) {
      event.startDate = updateEventDto.startDate ? new Date(updateEventDto.startDate) : null;
    }
    if (updateEventDto.endDate !== undefined) {
      event.endDate = updateEventDto.endDate ? new Date(updateEventDto.endDate) : null;
    }
    if (updateEventDto.isActive !== undefined) {
      event.isActive = updateEventDto.isActive;
    }

    return this.eventsRepository.save(event);
  }

  // 이벤트 삭제
  async remove(id: number): Promise<void> {
    await this.eventsRepository.delete(id);
  }
}
