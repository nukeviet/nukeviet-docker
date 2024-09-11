#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  TARGET="$(readlink "$SOURCE")"
  if [[ $TARGET == /* ]]; then
    SOURCE="$TARGET"
  else
    DIR="$( dirname "$SOURCE" )"
    SOURCE="$DIR/$TARGET"
  fi
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
cd "$DIR/"
DIR_PATH=$PWD

# Dừng và xóa các container nếu đang chạy
docker-compose down

# Tạo thư mục cần thiết
rm -rf "$DIR_PATH/src"
rm -rf "$DIR_PATH/_docker"
rm -rf "$DIR_PATH/db"

mkdir -p "$DIR_PATH/src"
mkdir -p "$DIR_PATH/_docker/mysql"
mkdir -p "$DIR_PATH/db"

# Lấy code NukeViet CMS
cd "$DIR_PATH/src"
git clone https://github.com/nukeviet/nukeviet.git ./

if ( (uname -s) 2>&1 ) | grep 'Linux' ; then
  find "$DIR_PATH/src" -name '.git' -type d -exec bash -c 'git config --global --add safe.directory ${0%/.git}' {} \;
fi

cd "$DIR_PATH"

: '

# Xóa các image custom đã tạo hay không
while true; do
  read -p "Xóa các docker image custom đã tạo [y/n(mặc định)]? " yn
  if [[ "$yn" = "y" || "$yn" = "y" ]] ; then
    echo "Xóa các image hstdt-*"
    for Repository in $(docker images --format '{{.Repository}}') ; do
      if [[ "$Repository" =~ ^hstdt- ]] ; then
        docker image rm -f "$Repository"
      fi
    done
    break
  elif [[ "$yn" = "n" || "$yn" = "N" || "$yn" = "" ]] ; then
    echo "Giữ lại các image hstdt-* nếu có"
    break
  else
    echo "Vui lòng nhập y hoặc n hoặc để trống"
  fi
done
'

#if [ -f "$DIR_PATH/conf/php82/.env" ] ; then
#  rm -f "$DIR_PATH/conf/php82/.env"
#fi
#cp "$DIR_PATH/.env" "$DIR_PATH/conf/php82/.env"

docker-compose up -d

# Chờ MariaDB chạy hoàn tất
attempt=0
DB_READY=0
while [ $attempt -le 59 ]; do
  attempt=$(( $attempt + 1 ))
  echo "Đợi mariadb sẵn sàng (lần $attempt)..."
  result=$( (docker logs dauthau_db) 2>&1 )
  if grep -q 'MariaDB init process done. Ready for start up' <<< $result ; then
    echo "MariaDB sẵn sàng!"
    DB_READY=1
    break
  fi
  if grep -q 'MariaDB upgrade not required' <<< $result ; then
    echo "MariaDB sẵn sàng!"
    DB_READY=1
    break
  fi
  sleep 2
done
if [[ ! "$DB_READY" -eq 1 ]]; then
  echo "Không khởi chạy MariaDB thành công, vui lòng kiểm tra lại"
  exit
fi

# Chờ nginx chạy hoàn tất
attempt=0
NGINX_READY=0
while [ $attempt -le 59 ]; do
  attempt=$(( $attempt + 1 ))
  echo "Đợi nginx sẵn sàng (lần $attempt)..."
  result=$( (docker logs dauthau_reverse_proxy) 2>&1 )
  if grep -q 'Configuration complete; ready for start up' <<< $result ; then
    echo "Nginx sẵn sàng!"
    NGINX_READY=1
    break
  fi
  sleep 2
done
if [[ ! "$NGINX_READY" -eq 1 ]]; then
  echo "Không khởi chạy nginx thành công, vui lòng kiểm tra lại"
  exit
fi

echo "Xong!"