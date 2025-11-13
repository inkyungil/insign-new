import { Injectable } from "@nestjs/common";
import { PassportSerializer } from "@nestjs/passport";

interface SerializedUser {
  id: number;
  username: string;
}

@Injectable()
export class SessionSerializer extends PassportSerializer {
  serializeUser(
    user: SerializedUser,
    done: (err: Error | null, id?: SerializedUser) => void,
  ) {
    done(null, user);
  }

  deserializeUser(
    payload: SerializedUser,
    done: (err: Error | null, payload?: SerializedUser) => void,
  ) {
    done(null, payload);
  }
}
