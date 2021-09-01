using Beefy;
using Beefy.gfx;
using Beefy.theme.dark;
using Beefy.theme;
using Beefy.widgets;
using System;
using System.IO;
using System.Collections;
using System.Diagnostics;
using System.Threading;

namespace iReplay
{
	class IRApp : BFApp
	{
		public struct DataEntry
		{
			public int mTick;
			public int64 mPosition;
		}

		const String cDataValidEventName = "Local\\IRSDKDataValidEvent";
		const String cMemMapFilaname = "Local\\IRSDKMemMapFileName";

		public Font mTinyMonoFont ~ delete _;
		public Font mSmFont ~ delete _;
		public Font mSmMonoFont ~ delete _;
		public Font mMedFont ~ delete _;
		public Font mMedMonoFont ~ delete _;
		public Font mLgMonoFont ~ delete _;
		public Image mMapCarImage ~ delete _;
		public Image mMapPointerImage ~ delete _;
		public Image mChevronImage ~ delete _;

		public WidgetWindow mConfigWindow;
		public Board mBoard;

		public double mDataTick;
		public Windows.Handle mFileMapping;
		public Windows.EventHandle mEvent;
		public uint8* mData;
		public int32 mNextDataTick = -1;
		public float mSpeed = 1.0f;
		public FileStream mStream ~ delete _;
		public int32 mCurDataTick = -1;
		public List<uint8> mImageData = new .() ~ delete _;
		public int32 mSharedMemorySize;

		public List<DataEntry> mHistory = new .() ~ delete _;

		public this()
		{
			gApp = this;
		}

		public override void Init()
		{
			base.Init();

			mSmFont = new Font()..Load(scope $"{mInstallDir}/fonts/Montserrat-Medium.ttf", 15);
			mMedFont = new Font()..Load(scope $"{mInstallDir}/fonts/Montserrat-SemiBold.ttf", 16);
			mTinyMonoFont = new Font()..Load("Segoe UI Bold", 12);
			mSmMonoFont = new Font()..Load("Segoe UI Bold", 15);
			mMedMonoFont = new Font()..Load("Segoe UI Bold", 18);
			mLgMonoFont = new Font()..Load("Segoe UI Bold", 22);
			//mMedFont = new Font()..Load("Arial", 30);

			mMapCarImage = Image.LoadFromFile(scope $"{mInstallDir}/images/MapCar.png");
			mMapPointerImage = Image.LoadFromFile(scope $"{mInstallDir}/images/MapPointer.png");
			mChevronImage = Image.LoadFromFile(scope $"{mInstallDir}/images/Chevron.png");

			DarkTheme aTheme = new DarkTheme();
			aTheme.Init();
			ThemeFactory.mDefault = aTheme;

			mBoard = new .();

			mConfigWindow = new WidgetWindow(null, "iReplay", 64, 64, 1024, 768, .QuitOnClose | .Caption | .SysMenu | .Minimize | .Resizable, mBoard);
		}

		public void ResyncToHistory()
		{
			int64 wantPos = -1;
			for (var dataEntry in mHistory)
			{
				if (dataEntry.mTick > mDataTick)
					break;
				wantPos = dataEntry.mPosition;
			}

			if (wantPos != -1)
			{
				mStream.Position = wantPos;
				mNextDataTick = -1;
			}
		}
		
		public override void Update(bool batchStart)
		{
			base.Update(batchStart);

			mDataTick += UpdateDelta * 1000 * mSpeed;

			while (true)
			{
				if (!mStream.CanRead)
					break;

				if (mNextDataTick == -1)
				{
					int pos = mStream.Position;
					mNextDataTick = mStream.Read<int32>();

					if (mNextDataTick == -1)
					{
						mImageData.Clear();

						int32 imageSize = mStream.Read<int32>();
						mImageData.Count = imageSize;

						mStream.TryRead((Span<uint8>)mImageData).IgnoreError();
						continue;
					}

					DataEntry dataEntry = .() { mTick = mNextDataTick, mPosition = mStream.Position - 4 };
					mHistory.Add(dataEntry);
				}

				if (mDataTick < mNextDataTick)
					break;
				
				mCurDataTick = mNextDataTick;

				uint8* ptr = mData;

				DecodeLoop:
				while (true)
				{
					Debug.Assert(ptr - mData < mSharedMemorySize);

					uint8 c = mStream.Read<uint8>().Value;
					int delta = -1;

					switch (c)
					{
					case 0xA4:
						break DecodeLoop;
					case 0xA3:
						delta = mStream.Read<int32>().Value;
					case 0xA2:
						delta = mStream.Read<uint16>().Value;
					case 0xA1:
						delta = mStream.Read<uint8>().Value;
					}

					if (delta != -1)
					{
						ptr += delta;
						c = mStream.Read<uint8>();
					}

					if (c == 0xA0)
						c = mStream.Read<uint8>();

					*(ptr++) = c;
				}

				Windows.SetEvent(mEvent);
				mNextDataTick = -1;
			}
		}

		public Result<void> Show(String str)
		{
			mStream = new .();
			Try!(mStream.Open(str, .Read));

			mSharedMemorySize = mStream.Read<int32>().Value;

			mFileMapping = Windows.CreateFileMappingA(Windows.Handle.InvalidHandle, null, Windows.PAGE_READWRITE, 0, (.)mSharedMemorySize, cMemMapFilaname);
			mEvent = Windows.CreateEventA(null, true, false, cDataValidEventName);
			mData = (.)Windows.MapViewOfFile(mFileMapping, Windows.FILE_MAP_WRITE, 0, 0, 0);

			return .Ok;
		}
	}

	static
	{
		public static IRApp gApp;
	}
}
