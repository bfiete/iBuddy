#pragma warning disable 168

using Beefy;
using iRacing;
using Beefy.widgets;
using Beefy.gfx;
using Beefy.theme.dark;
using Beefy.theme;
using System;
using Beefy.input;
using System.Diagnostics;

namespace iBuddy
{
	class IBApp : BFApp
	{
		public enum LapInputState
		{
			Disabled,
			Record,
			Compare
		}

		public IRSdk mIRSdk ~ delete _;

		public InputManager mInputManager ~ delete _;
		public InputDevice mInputDevice ~ delete _;

		public WidgetWindow mBoardWindow;
		public Board mBoard;

		public WidgetWindow mConfigWindow;
		public ConfigWidget mConfigWidget;

		public WidgetWindow mLapInputWindow;
		public LapInputWidget mLapInputWidget;
		
		public Font mTinyMonoFont ~ delete _;
		public Font mSmFont ~ delete _;
		public Font mSmMonoFont ~ delete _;
		public Font mMedFont ~ delete _;
		public Font mMedMonoFont ~ delete _;
		public Font mLgMonoFont ~ delete _;
		public Image mMapCarImage ~ delete _;
		public Image mMapPointerImage ~ delete _;
		public Image mChevronImage ~ delete _;
		public LapInputState mLapInputState;

		public this()
		{
			gApp = this;

			mIRSdk = new IRSdk();
		}

		public int32 GetWindowX(int32 width)
		{
			GetWorkspaceRect(var workspaceX, var workspaceY, var workspaceWidth, var workspaceHeight);
			if (workspaceWidth < 0)
				return 64;
			return (.)(workspaceX + workspaceWidth - width - 24);
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

			mConfigWidget = new .();
			mConfigWindow = new WidgetWindow(null, "iBuddy Config", GetWindowX(320), 200, 320, 240, .QuitOnClose | .Caption | .SysMenu | .Minimize, mConfigWidget);

			DarkTheme aTheme = new DarkTheme();
			aTheme.Init();
			ThemeFactory.mDefault = aTheme;

			mInputManager = new InputManager();
			CheckInputDevices();
		}

		public void CheckInputDevices()
		{
			if (mInputDevice != null)
			{
				String state = scope .();
				mInputDevice.GetState(state);
				//Debug.WriteLine("InputState: {}", state);

				if (state.StartsWith("!"))
				{
					DeleteAndNullify!(mInputDevice);
				}
			}

			if (mInputDevice == null)
			{
				String devices = scope .();

				/*Stopwatch sw = scope .();
				sw.Start();*/
				mInputManager.EnumerateInputDevices(devices);
				/*sw.Stop();
				Debug.WriteLine($"{sw.ElapsedMilliseconds}");*/

				for (var dev in devices.Split('\n'))
				{
					if (dev.IsEmpty)
						continue;

					var e = dev.Split('\t');
					StringView instName = e.GetNext();
					StringView prodName = e.GetNext();
					StringView guid = e.GetNext();
					if (prodName.StartsWith("Simucube 2"))
					{
						mInputDevice = mInputManager.CreateInputDevice(guid);
						if (mInputDevice != null)
						{
							String state = scope .();
							mInputDevice.GetState(state);
						}
					}
				}
			}
		}

		public override void Shutdown()
		{
			base.Shutdown();

			if (mBoardWindow != null)
				mBoardWindow.Close();
			if (mLapInputWindow != null)
				mLapInputWindow.Close();
		}

		public override void Update(bool batchStart)
		{
			base.Update(batchStart);

			mIRSdk.Update();

			mLapInputState = Enum.Parse<LapInputState>(mConfigWidget.mRecordCombo.Label).GetValueOrDefault();

			

			if (mIRSdk.IsRunning)
			{
				if (mBoard == null)
				{
					

					mBoard = new Board();
					BFWindowBase.Flags windowFlags = default;
					windowFlags |= .TopMost;
					//mWindow = new WidgetWindow(null, "iBuddy Relative", 660, 320, 600, 900 /*240*/, windowFlags, mBoard);
					mBoardWindow = new WidgetWindow(null, "iBuddy Relative", GetWindowX(640), 16, 640, 360, windowFlags, mBoard);
					mBoard.SetFocus();
				}
			}
			else
			{
				if (mBoardWindow != null)
				{
					mBoardWindow.Close();
					mBoardWindow = null;
					mBoard = null;
				}

				mLapInputState = .Disabled;
			}

			bool wantLapInputRecording = mLapInputState == .Record;
			if ((mLapInputState == .Disabled) || (mLapInputWidget?.mRecording != wantLapInputRecording))
			{
				if (mLapInputWindow != null)
				{
					mLapInputWindow.Close();
					mLapInputWindow = null;
					mLapInputWidget = null;
				}
			}

			if (mLapInputState != .Disabled)
			{
				if (mLapInputWindow == null)
				{
					mLapInputWidget = new LapInputWidget(wantLapInputRecording);
					BFWindowBase.Flags windowFlags = default;
					windowFlags |= .TopMost;
					mLapInputWindow = new WidgetWindow(null, "iBuddy Input", GetWindowX(616), 400, 616, 240, windowFlags, mLapInputWidget);
				}
			}

			if (mUpdateCnt % 60 == 0)
				CheckInputDevices();
		}

		public void Fail(StringView str)
		{
			Windows.MessageBoxA(default, str.ToScopeCStr!(), "IBUDDY ERROR", Windows.MB_ICONHAND | Windows.MB_OK);
		}
	}

	static
	{
		public static IBApp gApp;
	}
}
