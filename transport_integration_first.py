
hadoop = sc._jvm.org.apache.hadoop
hadoop_file_system = hadoop.fs.FileSystem.get(hadoop.conf.Configuration())

def select_hdfs_file(hdfs_path):
    files = hadoop_file_system.listFiles(hadoop.fs.Path(hdfs_path), False)
    while files.hasNext():
        file = f'{files.next().getPath()}'
        if '_SUCCESS' not in f'{file}':
            print(f"� HDFS ������ ���� '{file}'")
            return file

def load_from_hdfs(hdfs_path):
    hdfs_path = select_hdfs_file(hdfs_path)
    local_path = 'tmp/' + hdfs_path.split('/')[-1]

    hadoop_file_system.copyToLocalFile(False, hadoop.fs.Path(hdfs_path),hadoop.fs.Path(local_path))

    return local_path

def get_drive_client():
    def authenticate_by_pass():
        auth_service = AuthService(url='https://api/auth', allow_unverified_peer=True)
        return auth_service.authenticate_by_pass(login=f'{hdfs_login}', password=f'{hdfs_password}')

    drive_config = DriveClientConfig(url='https://api/drive', auth_provider=authenticate_by_pass, ssl_verify=False)
    drive_client = DriveClient(drive_config)
    return drive_client

def upload_to_drive2(drive_client, drive_name, content):
    RANGES_LENGTH = 128 * 1024 * 1024
    ATTEMTS_COUNT = 20

    content_total_size = len(content)
    for attempt in range(ATTEMTS_COUNT):
        try:
            drive_client.partial_upload_content(partial_upload_id, content_range_bytes, content_range_start, content_total_size)
        except Exception as exception:
            print(f"�������� '{drive_name}': ������� [{content_range_start}:{content_range_end}] �� ������� ��������� � {attempt} �� {ATTEMTS_COUNT} �������: {exception}")
        else:
            print(f"�������� '{drive_name}': ������� [{content_range_start}:{content_range_end}] �������� � {attempt} �� {ATTEMTS_COUNT} �������")
            break

def load_from_hdfs_to_drive(hdfs_paths, drive_name, drive2_link, archive_password):
    local_paths = [load_from_hdfs(hdfs_path) for hdfs_path in hdfs_paths]
    print(f"����� {hdfs_paths} ��������� �� HDFS � ��������� ��: {local_paths}")

    from py7zr import SevenZipFile
    local_path_7z = 'tmp/test.7z'
    with SevenZipFile(local_path_7z, 'w', password=f'{drive_pwd}') as archive:
        for local_path in local_paths:
            archive.write(local_path)
    print(f"������ 7z-����� '{local_path_7z}'")

    drive_client = get_drive_client()

    with open(local_path_7z, 'rb') as f:
        upload_to_drive(drive_client, drive_name, f.read())

    public_link = drive_client.create_public_link(drive_name, drive_link)

    for local_path in local_paths:
        os.remove(local_path)
    os.remove(local_path_7z)

    print(f"����� {hdfs_paths} ���� ��������� �� HDFS � Drive �� ���� '{drive_name}'. ����� ������� �� ������ '{public_link}', ������ �� ������ '{archive_password}'")

    return public_link

